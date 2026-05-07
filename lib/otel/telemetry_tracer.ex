defmodule Otel.TelemetryTracer do
  @moduledoc """
  Bridges BEAM `:telemetry.span/3` events into the OTel Trace
  pipeline. Trace pillar's analog of `Otel.LoggerHandler` (Logs)
  and `Otel.TelemetryReporter` (Metrics).

  Add to your supervision tree with the event prefixes that
  should be promoted to OTel spans:

      defmodule MyApp.Application do
        use Application

        @impl true
        def start(_type, _args) do
          children = [
            {Otel.TelemetryTracer, events: [
              [:my_app, :checkout],
              [:phoenix, :endpoint],
              [:my_app, :repo, :query]
            ]}
          ]

          Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
        end
      end

  Each entry in `events:` is the **prefix** (matches the first
  argument of `:telemetry.span/3`); the bridge subscribes to the
  three lifecycle events derived from it
  (`prefix ++ [:start | :stop | :exception]`).

  ## What lands in Tempo

  | OTel field | Source |
  |---|---|
  | `name` | event prefix joined by `.` — e.g. `[:my_app, :checkout]` → `"my_app.checkout"` |
  | `parent_span_id` | implicit from the calling process's current OTel context (works for nested `:telemetry.span/3` and mixed `with_span/4`) |
  | `attributes` | `start_metadata` ∪ `stop_metadata`, minus `:telemetry`-internal keys (see "Reserved metadata keys" below). All keys coerced to `String.t()` |
  | `status` | `:ok` on `:stop`; `:error` on `:exception` (description = `Exception.message/1` for exceptions, `inspect(reason)` for `:exit`/`:throw`) |
  | `exception.*` | `record_exception/4` on the `:exception` event, using `metadata.reason` + `metadata.stacktrace` |

  Span `kind` defaults to `INTERNAL`. Pass
  `metadata.span_kind: :server | :client | :producer | :consumer`
  on the `:start` event to override.

  ## Context propagation

  The `:start` handler runs synchronously in the calling process
  before the user function executes; `:stop` / `:exception`
  handlers run after. Between them, the OTel current-span ctx is
  the new span (stored in process dictionary keyed by the
  `:telemetry.span/3`-issued ref). This means:

  - Nested `:telemetry.span/3` calls automatically form a
    parent-child chain.
  - `:telemetry.span/3` ↔ `Otel.Trace.with_span/4` mixed in the
    same process also form a chain (both APIs share the
    process-dictionary ctx channel).
  - Cross-process work (`Task.async`, `GenServer.cast`, etc.)
    still requires explicit `Otel.Ctx.attach/1` of the captured
    parent ctx — same constraint as `with_span/4`.

  ## Reserved metadata keys

  `:telemetry.span/3` inserts a few internal keys into the
  metadata map (notably `:telemetry_span_context`, the
  start/stop matching ref). The bridge filters these so they
  don't leak as span attributes. Keys filtered:
  `:telemetry_span_context`, `:duration`, `:monotonic_time`,
  `:system_time`, `:kind`, `:reason`, `:stacktrace`, `:span_kind`.

  All remaining metadata keys are stringified (`to_string/1`)
  and merged onto the span as attributes.

  ## Lifecycle

  The bridge is a `GenServer` with `trap_exit: true`. Each
  configured event prefix attaches three handlers via
  `:telemetry.attach/4` keyed by `{__MODULE__, event_name,
  self()}`. `terminate/2` detaches all of them so a clean
  shutdown leaves no stale handlers.

  Multiple instances under different supervisors can co-exist
  — each instance owns handlers keyed by its own pid.

  ## References

  - `:telemetry.span/3`: <https://hexdocs.pm/telemetry/telemetry.html#span/3>
  - OTel Trace API §Span Creation: `opentelemetry-specification/specification/trace/api.md` L378-L414
  - OTel Trace API §record_exception: `trace/api.md` L654-L705
  """

  use GenServer
  use Otel.Common.Types

  @typedoc """
  A `:telemetry.span/3` event prefix — the first arg to
  `:telemetry.span/3`. The bridge subscribes to
  `prefix ++ [:start | :stop | :exception]` for each entry.
  """
  @type event_prefix :: [atom()]

  @typedoc """
  Options accepted by `start_link/1`. Both keys are optional —
  omitting `:events` yields a no-op tracer (no handlers
  attached).
  """
  @type opts :: [
          events: [event_prefix()],
          name: GenServer.name()
        ]

  @typedoc """
  Per-handler config passed via `:telemetry.attach/4`'s
  `config` argument and received as the 4th arg of
  `handle_event/4`.
  """
  @type handler_config :: %{prefix: event_prefix(), suffix: :start | :stop | :exception}

  @typedoc "GenServer state — the list of telemetry handler IDs we own."
  @type state :: %{handlers: [:telemetry.handler_id()]}

  @reserved_keys [
    :telemetry_span_context,
    :duration,
    :monotonic_time,
    :system_time,
    :kind,
    :reason,
    :stacktrace,
    :span_kind
  ]

  @spec start_link(opts :: opts()) :: GenServer.on_start()
  def start_link(opts) do
    events = Keyword.get(opts, :events, [])
    GenServer.start_link(__MODULE__, events, Keyword.take(opts, [:name]))
  end

  @impl true
  @spec init(events :: [event_prefix()]) :: {:ok, state()}
  def init(events) do
    Process.flag(:trap_exit, true)

    handlers =
      for prefix <- events,
          suffix <- [:start, :stop, :exception] do
        event_name = prefix ++ [suffix]
        id = {__MODULE__, event_name, self()}

        :telemetry.attach(
          id,
          event_name,
          &__MODULE__.handle_event/4,
          %{prefix: prefix, suffix: suffix}
        )

        id
      end

    {:ok, %{handlers: handlers}}
  end

  @impl true
  @spec terminate(reason :: term(), state :: state()) :: :ok
  def terminate(_reason, %{handlers: handlers}) do
    for id <- handlers, do: :telemetry.detach(id)
    :ok
  end

  @doc false
  @spec handle_event(
          event_name :: [atom()],
          measurements :: map(),
          metadata :: map(),
          config :: handler_config()
        ) :: :ok
  def handle_event(_event_name, _measurements, metadata, %{prefix: prefix, suffix: :start}) do
    span_ctx =
      Otel.Trace.start_span(span_name(prefix),
        kind: metadata[:span_kind] || :internal,
        attributes: filter_attrs(metadata)
      )

    prior = Otel.Trace.make_current(span_ctx)
    Process.put(slot_key(metadata), {span_ctx, prior})
    :ok
  end

  def handle_event(_event_name, _measurements, metadata, %{suffix: :stop}) do
    case Process.delete(slot_key(metadata)) do
      {span_ctx, prior} ->
        Otel.Trace.Span.set_attributes(span_ctx, filter_attrs(metadata))
        Otel.Trace.Span.set_status(span_ctx, Otel.Trace.Status.new(%{code: :ok}))
        Otel.Trace.Span.end_span(span_ctx)
        Otel.Trace.detach(prior)
        :ok

      nil ->
        :ok
    end
  end

  def handle_event(_event_name, _measurements, metadata, %{suffix: :exception}) do
    case Process.delete(slot_key(metadata)) do
      {span_ctx, prior} ->
        record_exception(span_ctx, metadata)
        Otel.Trace.Span.end_span(span_ctx)
        Otel.Trace.detach(prior)
        :ok

      nil ->
        :ok
    end
  end

  # Span name = prefix atoms joined by ".". `[:my_app, :add]` → "my_app.add".
  @spec span_name(prefix :: [atom()]) :: String.t()
  defp span_name(prefix) do
    prefix |> Enum.map_join(".", &Atom.to_string/1)
  end

  # Process-dictionary slot. Keyed by the ref that
  # `:telemetry.span/3` puts in metadata, so concurrent /
  # nested span pairs in the same process don't collide.
  @spec slot_key(metadata :: map()) :: {module(), reference()}
  defp slot_key(metadata) do
    {__MODULE__, metadata.telemetry_span_context}
  end

  # Drop telemetry-internal keys + stringify atom keys + coerce
  # values to `primitive_any()` so the OTLP encoder (which
  # crashes on atoms / tuples / pids per its happy-path policy)
  # can serialise them. Mirrors `Otel.LoggerHandler`'s coercion
  # path.
  @spec filter_attrs(metadata :: map()) :: %{String.t() => primitive_any()}
  defp filter_attrs(metadata) do
    metadata
    |> Map.drop(@reserved_keys)
    |> Map.new(fn {k, v} -> {to_string(k), to_primitive_any(v)} end)
  end

  # Recursive coercion to `primitive_any()`. Maps recurse with
  # `to_string(k)` on keys so `map<string, AnyValue>` holds at
  # every depth; lists recurse element-wise; everything else
  # delegates to `to_primitive/1` for the leaf coercion.
  @spec to_primitive_any(value :: term()) :: primitive_any()
  defp to_primitive_any(value) when is_map(value) and not is_struct(value) do
    Map.new(value, fn {k, v} -> {to_string(k), to_primitive_any(v)} end)
  end

  defp to_primitive_any(value) when is_list(value) do
    Enum.map(value, &to_primitive_any/1)
  end

  defp to_primitive_any(value), do: to_primitive(value)

  # Leaf coercion to `primitive()` — atoms (other than booleans
  # / nil), structs, tuples (other than `:bytes`), refs, pids,
  # etc. coerce to `String.t()` via `String.Chars` impl when
  # present, `inspect/1` otherwise. Same policy as
  # `Otel.LoggerHandler.to_primitive/1`.
  @spec to_primitive(value :: term()) :: primitive()
  defp to_primitive(nil), do: nil
  defp to_primitive(value) when is_boolean(value), do: value
  defp to_primitive(value) when is_binary(value), do: value
  defp to_primitive(value) when is_integer(value), do: value
  defp to_primitive(value) when is_float(value), do: value
  defp to_primitive({:bytes, bin} = value) when is_binary(bin), do: value

  defp to_primitive(value) do
    case String.Chars.impl_for(value) do
      nil -> inspect(value)
      _impl -> to_string(value)
    end
  end

  # `:telemetry.span/3`'s `:exception` event metadata shape
  # (per `:telemetry`'s docstring on `span/3`):
  # `%{kind: :error | :exit | :throw, reason: term(), stacktrace: list()}`
  # plus the original start/stop metadata.
  @spec record_exception(span_ctx :: Otel.Trace.SpanContext.t(), metadata :: map()) :: :ok
  defp record_exception(
         span_ctx,
         %{kind: :error, reason: %{__exception__: true} = exception} = metadata
       ) do
    Otel.Trace.Span.record_exception(span_ctx, exception, metadata[:stacktrace] || [])

    Otel.Trace.Span.set_status(
      span_ctx,
      Otel.Trace.Status.new(%{code: :error, description: Exception.message(exception)})
    )

    :ok
  end

  defp record_exception(span_ctx, %{kind: kind, reason: reason}) do
    Otel.Trace.Span.set_status(
      span_ctx,
      Otel.Trace.Status.new(%{code: :error, description: "#{kind}: #{inspect(reason)}"})
    )

    :ok
  end
end
