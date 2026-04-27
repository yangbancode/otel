defmodule Otel.SDK.Config.Selector do
  @moduledoc """
  Atom-name → canonical `{module, config}` normalization for SDK
  configuration values.

  Three input forms are accepted everywhere a module is selected:

  - **shortcut atom** (`:otlp`, `:console`, `:batch`, `:always_on`, ...) —
    spec-blessed enum names mapped through built-in tables to project
    modules. The shortcut set is closed; only spec values defined in
    `configuration/sdk-environment-variables.md` L122-L131, L243-L265,
    and L143-L152 are accepted.
  - **module atom** (e.g. `Otel.OTLP.Trace.SpanExporter.HTTP`) — direct
    module reference, normalized to `{Module, %{}}`.
  - **{module, config} tuple** — passed through unchanged. Always the
    canonical form a provider expects at its `start_link/1` boundary.

  Same normalizers serve both code paths — Mix Config (`config :otel_sdk,
  trace: [exporter: :otlp | Module | {Module, %{}}]`) and `OTEL_*` env
  vars (which can only ever produce a shortcut atom because the spec
  enums are strings).

  ## Public API

  | Function | Spec section |
  |---|---|
  | `trace_exporter/1` | `sdk-environment-variables.md` L243-L254 |
  | `metrics_exporter/1` | L244, L258-L265 |
  | `logs_exporter/1` | L245 |
  | `trace_processor/1` | `trace/sdk.md` §SpanProcessor (no env var) |
  | `logs_processor/1` | `logs/sdk.md` §LogRecordProcessor (no env var) |
  | `sampler/1` | L143-L152 |
  | `propagator/1` | L122-L131 (`OTEL_PROPAGATORS`) |

  ## Out of scope (future PRs)

  - `:zipkin`, `:prometheus` — exporters not implemented in this repo.
  - `:logging` — spec L254 deprecated, *"SHOULD NOT be supported by new
    implementations"*.
  - `:jaeger_remote` / `:parentbased_jaeger_remote` samplers — depend
    on a remote sampling protocol not yet implemented.
  - `:xray` sampler — third-party.
  """

  # ====== Trace exporters ======

  @doc """
  Normalizes a trace exporter spec to `{module, config}` or `:none`.
  """
  @spec trace_exporter(value :: atom() | module() | {module(), map()}) ::
          {module(), map()} | :none
  def trace_exporter(:otlp), do: {Otel.OTLP.Trace.SpanExporter.HTTP, %{}}
  def trace_exporter(:console), do: {Otel.SDK.Trace.SpanExporter.Console, %{}}
  def trace_exporter(:none), do: :none

  def trace_exporter({module, config}) when is_atom(module) and is_map(config),
    do: {module, config}

  def trace_exporter(module) when is_atom(module), do: {module, %{}}

  # ====== Metrics exporters ======

  @doc """
  Normalizes a metrics exporter spec to `{module, config}` or `:none`.
  """
  @spec metrics_exporter(value :: atom() | module() | {module(), map()}) ::
          {module(), map()} | :none
  def metrics_exporter(:otlp), do: {Otel.OTLP.Metrics.MetricExporter.HTTP, %{}}
  def metrics_exporter(:console), do: {Otel.SDK.Metrics.MetricExporter.Console, %{}}
  def metrics_exporter(:none), do: :none

  def metrics_exporter({module, config}) when is_atom(module) and is_map(config),
    do: {module, config}

  def metrics_exporter(module) when is_atom(module), do: {module, %{}}

  # ====== Logs exporters ======

  @doc """
  Normalizes a logs exporter spec to `{module, config}` or `:none`.
  """
  @spec logs_exporter(value :: atom() | module() | {module(), map()}) ::
          {module(), map()} | :none
  def logs_exporter(:otlp), do: {Otel.OTLP.Logs.LogRecordExporter.HTTP, %{}}
  def logs_exporter(:console), do: {Otel.SDK.Logs.LogRecordExporter.Console, %{}}
  def logs_exporter(:none), do: :none

  def logs_exporter({module, config}) when is_atom(module) and is_map(config),
    do: {module, config}

  def logs_exporter(module) when is_atom(module), do: {module, %{}}

  # ====== Span processors ======

  @doc """
  Normalizes a span processor selector to a module reference. The
  caller wraps it with the exporter + processor knobs at composition
  time.
  """
  @spec trace_processor(value :: atom() | module()) :: module()
  def trace_processor(:batch), do: Otel.SDK.Trace.SpanProcessor.Batch
  def trace_processor(:simple), do: Otel.SDK.Trace.SpanProcessor.Simple
  def trace_processor(module) when is_atom(module), do: module

  # ====== LogRecord processors ======

  @doc """
  Normalizes a log record processor selector to a module reference.
  """
  @spec logs_processor(value :: atom() | module()) :: module()
  def logs_processor(:batch), do: Otel.SDK.Logs.LogRecordProcessor.Batch
  def logs_processor(:simple), do: Otel.SDK.Logs.LogRecordProcessor.Simple
  def logs_processor(module) when is_atom(module), do: module

  # ====== Trace samplers ======

  @doc """
  Normalizes a sampler selector to `{module, opts}` (the shape the
  built-in `Otel.SDK.Trace.Sampler.new/1` consumes).

  Accepts spec enum atoms (`:always_on`, `:parentbased_always_on`, ...),
  the parameterized `{:traceidratio, ratio}` /
  `{:parentbased_traceidratio, ratio}` tuples, a custom module, or a
  `{module, opts}` tuple passed through unchanged.
  """
  @spec sampler(value :: atom() | {atom() | module(), term()}) :: {module(), term()}
  def sampler(:always_on), do: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}
  def sampler(:always_off), do: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}

  def sampler(:parentbased_always_on),
    do: {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}

  def sampler(:parentbased_always_off),
    do: {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}}}

  # Spec L147: traceidratio defaults to 1.0 when no arg is supplied.
  def sampler(:traceidratio), do: sampler({:traceidratio, 1.0})

  def sampler(:parentbased_traceidratio),
    do: sampler({:parentbased_traceidratio, 1.0})

  def sampler({:traceidratio, ratio}) when is_float(ratio),
    do: {Otel.SDK.Trace.Sampler.TraceIdRatioBased, ratio}

  def sampler({:parentbased_traceidratio, ratio}) when is_float(ratio),
    do:
      {Otel.SDK.Trace.Sampler.ParentBased,
       %{root: {Otel.SDK.Trace.Sampler.TraceIdRatioBased, ratio}}}

  def sampler({module, opts}) when is_atom(module), do: {module, opts}
  def sampler(module) when is_atom(module), do: {module, %{}}

  # ====== Propagators ======

  @doc """
  Normalizes a single-propagator selector to a module reference.

  Spec L122-L131 enumerates eight known values; this SDK
  implements three: `:tracecontext`, `:baggage`, and `:none`.
  Other spec-named propagators (`:b3`, `:b3multi`, `:jaeger`,
  `:xray`, `:ottrace`) raise `ArgumentError` — their behaviours
  are not bundled in `:otel_api`.

  Custom propagator modules pass through unchanged so users can
  plug their own implementations of
  `Otel.API.Propagator.TextMap`.
  """
  @spec propagator(value :: atom() | module()) :: module()
  def propagator(:tracecontext), do: Otel.API.Propagator.TextMap.TraceContext
  def propagator(:baggage), do: Otel.API.Propagator.TextMap.Baggage
  def propagator(:none), do: Otel.API.Propagator.TextMap.Noop

  def propagator(name) when name in [:b3, :b3multi, :jaeger, :xray, :ottrace] do
    raise ArgumentError,
          "propagator #{inspect(name)} is not implemented in this SDK — " <>
            "supported built-ins: :tracecontext, :baggage, :none"
  end

  def propagator(module) when is_atom(module), do: module
end
