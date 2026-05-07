defmodule Otel.TelemetrySpanDecorator do
  @moduledoc """
  `@span` annotation that auto-wraps a function in
  `:telemetry.span/3`. Companion to `Otel.TelemetryTracer` —
  the tracer turns telemetry spans into OTel spans, the
  decorator removes the boilerplate of wrapping function
  bodies manually.

  ## Usage

      defmodule MyApp.Calculator do
        use Otel.TelemetrySpanDecorator

        @span [:my_app, :calculator, :add]
        def add(a, b) do
          a + b
        end
      end

  Compiles to roughly:

      def add(a, b) do
        :telemetry.span(
          [:my_app, :calculator, :add],
          %{
            :"code.function.name" => "MyApp.Calculator.add",
            :"code.file.path" => "/abs/.../calculator.ex",
            :"code.line.number" => 4
          },
          fn -> {a + b, %{}} end
        )
      end

  The event prefix passed to `@span` must match an entry in
  the `Otel.TelemetryTracer`'s `events:` list — registration
  is the user's responsibility.

  ## Auto-injected attributes

  Always emitted, no opt-out (aligns with the OTel `code.*`
  registry — `semantic-conventions/registry/attributes/code.md`):

  | Attribute | Source |
  |---|---|
  | `code.function.name` | `"\#{inspect(env.module)}.\#{name}"` |
  | `code.file.path` | `env.file` |
  | `code.line.number` | `env.line` |

  ## Optional argument / return capture

  Use the keyword form to opt in:

      @span event: [:my_app, :calculator, :sub], capture_io: true
      def sub(a, b), do: a - b

  When enabled:

  | Where | Captured | Source |
  |---|---|---|
  | `start_metadata.__args__` | `%{<arg_name> => <value>}` | function args, source-name keys |
  | `stop_metadata.__result__` | function's return value | last expression |

  Plain vars and default args (`x \\\\ 1`) keep their
  original name; pattern-match args (`%{...}`, `[h | t]`,
  etc.) fall back to a positional `:arg_<idx>` name;
  underscore-prefixed args (`_ignored`) keep the leading
  `_`. The `__args__` / `__result__` magic names follow the
  `__name__` convention (mirrors `__struct__`, `__info__`)
  to avoid collision with any user arg literally named
  `args` or `result`.

  > **Privacy note** — when `capture_io: true`, all argument
  > values AND the return value flow into the span attribute
  > set. Avoid on functions whose args / returns carry
  > secrets or PII unless your collector / sampler strips
  > them.

  > **Searchability note** — `__args__` and `__result__` are
  > nested `kvlist_value` AnyValue attributes — spec-correct
  > per `opentelemetry-specification/specification/common/README.md`
  > L41-54 ("arbitrary deep nesting of values for arrays and
  > maps is allowed") and OTLP `common/v1/common.proto` L25-51
  > (`kvlist_value` is a first-class `AnyValue` variant).
  > Backend support for indexing inner fields varies — Tempo
  > (LGTM 0.26.0) displays them in the span detail view but
  > does not index them for `/api/search?tags=` lookup. To
  > make a field tag-searchable on Tempo, set it as a
  > top-level attribute inside the function body via
  > `Otel.Trace.Span.set_attribute(Otel.Trace.current_span(),
  > key, value)`.

  ## Multi-clause functions

  Place `@span` once before the **first** clause; the
  decorator wraps all clauses of the same `name/arity` via
  `defoverridable + super`. Pattern-matching dispatch happens
  inside the wrapped function, so exactly one span is emitted
  per call regardless of which clause matched.

      @span [:my_app, :calculator, :sign]
      def sign(0), do: :zero
      def sign(_), do: :nonzero

  ## Span shape

  - `name`: derived from event prefix (`[:a, :b]` →
    `"a.b"`) — same convention as `Otel.TelemetryTracer`.
  - `kind`: always `:internal` (no override; use
    `Otel.Trace.with_span/4` directly for non-internal kinds).
  - `status`: `:ok` on normal return, `:error` on exception
    (handled by `:telemetry.span/3`'s `:exception` event).
  - `attributes`: `code.*` always; `__args__` / `__result__`
    only when `capture_io: true`.

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

  @typedoc """
  Options accepted in the keyword form of `@span`.

  - `:event` — required event prefix.
  - `:capture_io` — when `true`, includes `__args__` in
    start metadata and `__result__` in stop metadata.
    Defaults to `false`.
  """
  @type span_opts :: [event: event_prefix(), capture_io: boolean()]

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

      attr ->
        Module.delete_attribute(env.module, :span)
        {event_prefix, opts} = parse_span_attr(attr)
        capture_io = Keyword.get(opts, :capture_io, false)

        arg_names =
          args
          |> Enum.with_index()
          |> Enum.map(fn {arg, idx} -> arg_name(arg, idx) end)

        Module.put_attribute(
          env.module,
          :__otel_decorated__,
          {kind, name, length(args), event_prefix, arg_names, capture_io,
           %{file: env.file, line: env.line}}
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
      |> Enum.uniq_by(fn {kind, name, arity, _event, _arg_names, _capture_io, _env_meta} ->
        {kind, name, arity}
      end)

    overrides = Enum.map(decorated, &generate_override(&1, env.module))

    quote do
      (unquote_splicing(overrides))
    end
  end

  # Plain list form (`@span [:my_app, :process]`) keeps current
  # behaviour. Keyword form (`@span event: [...], capture_io: true`)
  # parses options. `Keyword.keyword?/1` distinguishes the two —
  # `[:my_app, :process]` is all atoms (returns false), while
  # `[event: [...], capture_io: true]` is all 2-tuples (returns true).
  @spec parse_span_attr(attr :: list()) :: {event_prefix(), keyword()}
  defp parse_span_attr(attr) when is_list(attr) do
    if Keyword.keyword?(attr) and attr != [] do
      Keyword.pop!(attr, :event)
    else
      {attr, []}
    end
  end

  # Emit `defoverridable` + override `def`/`defp` for one
  # decorated function. The override calls `super/N` so all
  # clauses of the original definition still pattern-match
  # inside the span.
  @spec generate_override(
          decorated ::
            {atom(), atom(), non_neg_integer(), event_prefix(), [atom()], boolean(), map()},
          module :: module()
        ) :: Macro.t()
  defp generate_override(
         {kind, name, arity, event_prefix, arg_names, capture_io, env_meta},
         module
       ) do
    vars = Macro.generate_arguments(arity, module)
    function_name = "#{inspect(module)}.#{name}"
    start_attrs_ast = build_start_attrs(function_name, env_meta, capture_io, arg_names, vars)
    span_call = build_span_call(event_prefix, start_attrs_ast, vars, capture_io)

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

  # Wrap `super(...)` in `:telemetry.span/3`. `result` is bound
  # and consumed within the same `quote do ... end` block so
  # macro hygiene keeps the binding intact.
  #
  # `generated: true` marks the generated AST so that
  # type-system warnings on always-raising user functions
  # (where `result = super(...)` would be flagged as never
  # matching `none()`) are suppressed.
  @spec build_span_call(
          event_prefix :: event_prefix(),
          start_attrs_ast :: Macro.t(),
          vars :: [Macro.t()],
          capture_io :: boolean()
        ) :: Macro.t()
  defp build_span_call(event_prefix, start_attrs_ast, vars, true) do
    quote generated: true do
      :telemetry.span(
        unquote(event_prefix),
        unquote(start_attrs_ast),
        fn ->
          result = super(unquote_splicing(vars))
          {result, %{__result__: result}}
        end
      )
    end
  end

  defp build_span_call(event_prefix, start_attrs_ast, vars, false) do
    quote generated: true do
      :telemetry.span(
        unquote(event_prefix),
        unquote(start_attrs_ast),
        fn ->
          {super(unquote_splicing(vars)), %{}}
        end
      )
    end
  end

  # Build start metadata. Always carries `code.*`; when
  # `capture_io` is true, also carries `__args__` mapping
  # source-text arg names to runtime values.
  @spec build_start_attrs(
          function_name :: String.t(),
          env_meta :: %{file: String.t(), line: non_neg_integer()},
          capture_io :: boolean(),
          arg_names :: [atom()],
          vars :: [Macro.t()]
        ) :: Macro.t()
  defp build_start_attrs(function_name, env_meta, false, _arg_names, _vars) do
    quote do
      %{
        :"code.function.name" => unquote(function_name),
        :"code.file.path" => unquote(env_meta.file),
        :"code.line.number" => unquote(env_meta.line)
      }
    end
  end

  defp build_start_attrs(function_name, env_meta, true, arg_names, vars) do
    args_map_ast = build_args_map(arg_names, vars)

    quote do
      %{
        :"code.function.name" => unquote(function_name),
        :"code.file.path" => unquote(env_meta.file),
        :"code.line.number" => unquote(env_meta.line),
        :__args__ => unquote(args_map_ast)
      }
    end
  end

  # Build a flat `%{arg_name: var, ...}` AST. All args
  # captured, underscore-prefixed included — privacy filtering
  # is the caller's responsibility.
  @spec build_args_map(arg_names :: [atom()], vars :: [Macro.t()]) :: Macro.t()
  defp build_args_map(arg_names, vars) do
    kvs = Enum.zip(arg_names, vars)
    {:%{}, [], kvs}
  end

  # Extract the source-text name of a single function arg.
  # Plain var (`x`) → `:x`. Default-arg (`x \\ 1`) → `:x`.
  # Underscore (`_x`, `_`) → keeps the leading underscore.
  # Pattern args (`%{}`, `[h | t]`, structs, etc.) →
  # positional `:arg_<idx>`.
  @spec arg_name(arg :: Macro.t(), idx :: non_neg_integer()) :: atom()
  defp arg_name({:\\, _, [{name, _, ctx}, _default]}, _idx) when is_atom(name) and is_atom(ctx) do
    name
  end

  defp arg_name({name, _, ctx}, _idx) when is_atom(name) and is_atom(ctx) do
    name
  end

  defp arg_name(_other, idx), do: :"arg_#{idx}"
end
