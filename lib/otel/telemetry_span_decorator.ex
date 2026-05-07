defmodule Otel.TelemetrySpanDecorator do
  @moduledoc """
  `@span` annotation that auto-wraps a function in
  `:telemetry.span/3`. Companion to `Otel.TelemetryTracer` —
  the tracer turns telemetry spans into OTel spans, the
  decorator removes the boilerplate of wrapping function
  bodies manually.

  ## Usage

      defmodule MyApp.Worker do
        use Otel.TelemetrySpanDecorator

        @span [:my_app, :worker, :process]
        def process(job, opts) do
          handle(job, opts)
        end
      end

  Compiles to roughly:

      def process(job, opts) do
        :telemetry.span(
          [:my_app, :worker, :process],
          %{"job" => job, "opts" => opts},
          fn -> {handle(job, opts), %{}} end
        )
      end

  The event prefix passed to `@span` must match an entry in
  the `Otel.TelemetryTracer`'s `events:` list — registration
  is the user's responsibility (Phase 1).

  ## Auto-captured metadata

  | Where | Captured | Source |
  |---|---|---|
  | `start_metadata` | each named argument | function args, by source name |
  | `stop_metadata` | `:result` | function's return value |

  Plain vars and default args (`x \\\\ 1`) keep their original
  name; pattern-match args (`%{...}`, `[h | t]`, etc.) fall
  back to a positional `:arg_<idx>` name; underscore-prefixed
  args (`_ignored`) keep the leading `_` in the metadata key
  (no drop). Keys are atom-typed per `:telemetry` convention;
  `Otel.TelemetryTracer` stringifies on the OTel side.

  > **Privacy note** — all argument values AND the return
  > value flow into the span attribute set. Avoid `@span` on
  > functions whose args / returns carry secrets or PII unless
  > your collector / sampler strips them.

  ## Multi-clause functions

  Place `@span` once before the **first** clause; the
  decorator wraps all clauses of the same `name/arity` via
  `defoverridable + super`. Pattern-matching dispatch happens
  inside the wrapped function, so exactly one span is emitted
  per call regardless of which clause matched.

      @span [:my_app, :foo]
      def foo(0), do: :zero
      def foo(_), do: :nonzero

  ## Span shape

  - `name`: derived from event prefix (`[:a, :b]` →
    `"a.b"`) — same convention as `Otel.TelemetryTracer`.
  - `kind`: always `:internal` (no override in Phase 1; use
    `Otel.Trace.with_span/4` directly for non-internal kinds).
  - `status`: `:ok` on normal return, `:error` on exception
    (handled by `:telemetry.span/3`'s `:exception` event).
  - `attributes`: start-side from auto-captured args;
    stop-side empty.

  ## Implementation

  Built on `@on_definition` + `@before_compile` +
  `defoverridable`. The `@on_definition` callback records
  each `def` / `defp` whose preceding `@span` attribute is
  set; the `@before_compile` macro emits one
  `defoverridable` + override per recorded `name/arity`.
  Multi-clause definitions only need one override because
  `super(...)` dispatches into the original clauses.
  """

  @typedoc """
  An event prefix accepted by `@span` — same shape as
  `:telemetry.span/3`'s first argument.
  """
  @type event_prefix :: [atom()]

  @doc false
  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :span, accumulate: false)
      Module.register_attribute(__MODULE__, :__otel_decorated__, accumulate: true)

      @on_definition Otel.TelemetrySpanDecorator
      @before_compile Otel.TelemetrySpanDecorator
    end
  end

  @doc false
  @spec __on_definition__(
          env :: Macro.Env.t(),
          kind :: :def | :defp | :defmacro | :defmacrop,
          name :: atom(),
          args :: [Macro.t()],
          guards :: [Macro.t()],
          body :: term()
        ) :: :ok
  def __on_definition__(env, kind, name, args, _guards, _body) when kind in [:def, :defp] do
    case Module.get_attribute(env.module, :span) do
      nil ->
        :ok

      event_prefix ->
        Module.delete_attribute(env.module, :span)

        arg_names =
          args
          |> Enum.with_index()
          |> Enum.map(fn {arg, idx} -> arg_name(arg, idx) end)

        Module.put_attribute(
          env.module,
          :__otel_decorated__,
          {kind, name, length(args), event_prefix, arg_names}
        )
    end
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: :ok

  @doc false
  defmacro __before_compile__(env) do
    decorated =
      env.module
      |> Module.get_attribute(:__otel_decorated__)
      |> Kernel.||([])
      |> Enum.uniq_by(fn {kind, name, arity, _event, _arg_names} -> {kind, name, arity} end)

    overrides = Enum.map(decorated, &generate_override(&1, env.module))

    quote do
      (unquote_splicing(overrides))
    end
  end

  # Emit `defoverridable` + override `def`/`defp` for one
  # decorated function. The override calls `super/N` so all
  # clauses of the original definition still pattern-match
  # inside the span.
  @spec generate_override(
          decorated :: {atom(), atom(), non_neg_integer(), event_prefix(), [atom()]},
          module :: module()
        ) :: Macro.t()
  defp generate_override({kind, name, arity, event_prefix, arg_names}, module) do
    vars = Macro.generate_arguments(arity, module)
    metadata_map = build_metadata_map(arg_names, vars)
    span_call = build_span_call(event_prefix, metadata_map, vars)

    case kind do
      :def ->
        quote do
          defoverridable [{unquote(name), unquote(arity)}]

          def unquote(name)(unquote_splicing(vars)) do
            unquote(span_call)
          end
        end

      :defp ->
        quote do
          defoverridable [{unquote(name), unquote(arity)}]

          defp unquote(name)(unquote_splicing(vars)) do
            unquote(span_call)
          end
        end
    end
  end

  # Wrap `super(...)` in `:telemetry.span/3`. The 2-tuple
  # `{result, stop_meta}` matches `:telemetry.span/3`'s
  # expected span_function shape (return value + stop_metadata).
  # `stop_meta` carries the result under `:result` so the
  # OTel span ends up with both args (start) and return value
  # (stop) as attributes.
  #
  # `generated: true` marks the generated AST so that
  # type-system warnings on always-raising user functions
  # (where `result = super(...)` would be flagged as never
  # matching `none()`) are suppressed.
  @spec build_span_call(
          event_prefix :: event_prefix(),
          metadata_map :: Macro.t(),
          vars :: [Macro.t()]
        ) :: Macro.t()
  defp build_span_call(event_prefix, metadata_map, vars) do
    quote generated: true do
      :telemetry.span(
        unquote(event_prefix),
        unquote(metadata_map),
        fn ->
          result = super(unquote_splicing(vars))
          {result, %{result: result}}
        end
      )
    end
  end

  # Build an `%{arg_name: var, ...}` AST (atom-keyed —
  # `:telemetry` metadata convention). `Otel.TelemetryTracer`
  # stringifies keys on its side. All args are captured,
  # including underscore-prefixed ones — privacy is the
  # caller's responsibility.
  @spec build_metadata_map(arg_names :: [atom()], vars :: [Macro.t()]) :: Macro.t()
  defp build_metadata_map(arg_names, vars) do
    kvs = Enum.zip(arg_names, vars)
    {:%{}, [], kvs}
  end

  # Extract the source-text name of a single function arg.
  # Plain var (`x`) → `:x`. Default-arg (`x \\ 1`) → `:x`.
  # Underscore (`_x`, `_`) → keeps the leading underscore so
  # `build_metadata_map/2` can drop it. Pattern args (`%{}`,
  # `[h | t]`, structs, etc.) → positional `:arg_<idx>`.
  @spec arg_name(arg :: Macro.t(), idx :: non_neg_integer()) :: atom()
  defp arg_name({:\\, _, [{name, _, ctx}, _default]}, _idx) when is_atom(name) and is_atom(ctx) do
    name
  end

  defp arg_name({name, _, ctx}, _idx) when is_atom(name) and is_atom(ctx) do
    name
  end

  defp arg_name(_other, idx), do: :"arg_#{idx}"
end
