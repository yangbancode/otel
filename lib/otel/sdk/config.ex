defmodule Otel.SDK.Config do
  @moduledoc """
  Composes provider configuration from two layers, in precedence
  order from highest to lowest:

  1. **Programmatic** — anything the caller passes directly to a
     provider's `start_link(config: ...)` overrides the layers
     below. (Outside this module's scope: providers receive the
     map this module produces and merge it with the caller's
     `start_link` config.)
  2. **Application env** — `Application.get_env(:otel, pillar,
     [])`. Configure the SDK declaratively from
     `config/runtime.exs` or `config/<env>.exs`.
  3. **Built-in defaults** — defined inline below. Several
     components are *hardcoded* and not configurable:
     Sampler (`parentbased_always_on`), IdGenerator (random),
     SpanProcessor / LogRecordProcessor (batch), and **exporter
     (OTLP/HTTP)**. To stop emitting telemetry, set
     `config :otel, disabled: true`.

  ## Configuration UX

  The SDK reads *only* Application env. Bridge any OS env vars
  you need from `runtime.exs` — the Phoenix `PHX_SERVER` pattern:

  ```elixir
  # config/runtime.exs
  config :otel,
    disabled: System.get_env("OTEL_SDK_DISABLED") == "true",
    trace: [
      resource: Otel.SDK.Resource.create(%{
        "service.name" => System.get_env("OTEL_SERVICE_NAME") || "my_app"
      })
    ],
    metrics: [
      resource: Otel.SDK.Resource.create(%{
        "service.name" => System.get_env("OTEL_SERVICE_NAME") || "my_app"
      })
    ],
    logs: [
      resource: Otel.SDK.Resource.create(%{
        "service.name" => System.get_env("OTEL_SERVICE_NAME") || "my_app"
      })
    ]
  ```

  ## Public API

  | Function | Returns |
  |---|---|
  | `disabled?/0` | `Application.get_env(:otel, :disabled) == true`; `Application.start/2` skips registering providers when true |
  | `trace/0` | TracerProvider config map |
  | `metrics/0` | MeterProvider config map |
  | `logs/0` | LoggerProvider config map |
  | `propagator/0` | Global TextMap propagator (single module or `{Composite, [...]}`) |

  ## References

  - OTel Trace SDK: `opentelemetry-specification/specification/trace/sdk.md`
  - OTel Metrics SDK: `opentelemetry-specification/specification/metrics/sdk.md`
  - OTel Logs SDK: `opentelemetry-specification/specification/logs/sdk.md`
  """

  require Logger

  # ====== General ======

  @doc """
  Returns `true` when `config :otel, disabled: true`.

  Bridge `OTEL_SDK_DISABLED` from `runtime.exs` if you need to
  toggle via OS env (Phoenix-style):

      # config/runtime.exs
      config :otel, disabled: System.get_env("OTEL_SDK_DISABLED") == "true"

  Spec L113-L114 — *"Disable the SDK for all signals... If `true`,
  a no-op SDK implementation will be used for all telemetry signals.
  Any propagators set via the `OTEL_PROPAGATORS` environment variable
  will be non-no-op."*
  """
  @spec disabled?() :: boolean()
  def disabled? do
    Application.get_env(:otel, :disabled, false) == true
  end

  # ====== Trace ======

  @doc """
  Builds the TracerProvider config map by composing defaults,
  Application env, and `OTEL_*` env vars.
  """
  @spec trace() :: map()
  def trace do
    pillar = Application.get_env(:otel, :trace, [])

    %{
      resource: Keyword.get(pillar, :resource, Otel.SDK.Resource.default()),
      processors: build_trace_processors(pillar),
      span_limits: build_span_limits(pillar)
    }
  end

  @spec build_trace_processors(pillar :: keyword()) ::
          [{module(), Otel.SDK.Trace.SpanProcessor.config()}]
  defp build_trace_processors(pillar) do
    case Keyword.get(pillar, :processors) do
      nil -> default_trace_processors(pillar)
      processors -> processors
    end
  end

  @spec default_trace_processors(pillar :: keyword()) ::
          [{module(), Otel.SDK.Trace.SpanProcessor.config()}]
  defp default_trace_processors(_pillar) do
    [{Otel.SDK.Trace.SpanProcessor, %{exporter: {Otel.OTLP.Trace.SpanExporter, %{}}}}]
  end

  # Limits are hardcoded to spec defaults (`%Otel.SDK.Trace.SpanLimits{}`).
  # The `:span_limits` Application-env keyword is retained as an
  # advanced override for tests that need to exercise the
  # limit-enforcement code paths with small caps; it is not part
  # of the documented user surface.
  @spec build_span_limits(pillar :: keyword()) :: Otel.SDK.Trace.SpanLimits.t()
  defp build_span_limits(pillar) do
    case Keyword.get(pillar, :span_limits) do
      nil -> %Otel.SDK.Trace.SpanLimits{}
      override -> struct(Otel.SDK.Trace.SpanLimits, normalize_struct_or_keyword(override))
    end
  end

  @spec normalize_struct_or_keyword(value :: keyword() | map() | struct()) :: map()
  defp normalize_struct_or_keyword(value) when is_map(value), do: Map.delete(value, :__struct__)
  defp normalize_struct_or_keyword(value) when is_list(value), do: Enum.into(value, %{})

  # ====== Metrics ======

  @doc """
  Builds the MeterProvider config map.
  """
  @spec metrics() :: map()
  def metrics do
    pillar = Application.get_env(:otel, :metrics, [])

    %{
      resource: Keyword.get(pillar, :resource, Otel.SDK.Resource.default()),
      readers: build_metrics_readers(pillar),
      exemplar_filter: build_exemplar_filter(pillar)
    }
  end

  # Hardcoded to `:trace_based` (spec default per
  # `metrics/sdk.md` L1123). The `:exemplar_filter`
  # Application-env keyword is retained as an advanced
  # override for tests that exercise the `:always_on` /
  # `:always_off` filter paths; it is not part of the
  # documented user surface.
  @spec build_exemplar_filter(pillar :: keyword()) :: Otel.SDK.Metrics.Exemplar.Filter.t()
  defp build_exemplar_filter(pillar) do
    Keyword.get(pillar, :exemplar_filter, :trace_based)
  end

  @spec build_metrics_readers(pillar :: keyword()) ::
          [{module(), Otel.SDK.Metrics.MetricReader.config()}]
  defp build_metrics_readers(pillar) do
    case Keyword.get(pillar, :readers) do
      nil -> default_metrics_readers(pillar)
      readers -> readers
    end
  end

  # Reader interval / timeout are hardcoded to spec defaults
  # (`metrics/sdk.md` L1450-L1453: `exportIntervalMillis`
  # `60000`, `exportTimeoutMillis` `30000`).
  # `OTEL_METRIC_EXPORT_INTERVAL` / `OTEL_METRIC_EXPORT_TIMEOUT`
  # env vars and the `:reader_config` Application-env keyword
  # are no longer read.
  @spec default_metrics_readers(pillar :: keyword()) ::
          [{module(), Otel.SDK.Metrics.MetricReader.config()}]
  defp default_metrics_readers(_pillar) do
    [
      {Otel.SDK.Metrics.MetricReader.PeriodicExporting,
       %{
         exporter: {Otel.OTLP.Metrics.MetricExporter, %{}},
         export_interval_ms: 60_000,
         export_timeout_ms: 30_000
       }}
    ]
  end

  # ====== Logs ======

  @doc """
  Builds the LoggerProvider config map.
  """
  @spec logs() :: map()
  def logs do
    pillar = Application.get_env(:otel, :logs, [])

    %{
      resource: Keyword.get(pillar, :resource, Otel.SDK.Resource.default()),
      processors: build_logs_processors(pillar),
      log_record_limits: build_log_record_limits(pillar)
    }
  end

  # See `build_span_limits/1`: same advanced-override semantics
  # for `:log_record_limits` Application-env keyword.
  @spec build_log_record_limits(pillar :: keyword()) :: Otel.SDK.Logs.LogRecordLimits.t()
  defp build_log_record_limits(pillar) do
    case Keyword.get(pillar, :log_record_limits) do
      nil -> %Otel.SDK.Logs.LogRecordLimits{}
      override -> struct(Otel.SDK.Logs.LogRecordLimits, normalize_struct_or_keyword(override))
    end
  end

  @spec build_logs_processors(pillar :: keyword()) ::
          [{module(), Otel.SDK.Logs.LogRecordProcessor.config()}]
  defp build_logs_processors(pillar) do
    case Keyword.get(pillar, :processors) do
      nil -> default_logs_processors(pillar)
      processors -> processors
    end
  end

  @spec default_logs_processors(pillar :: keyword()) ::
          [{module(), Otel.SDK.Logs.LogRecordProcessor.config()}]
  defp default_logs_processors(_pillar) do
    [
      {Otel.SDK.Logs.LogRecordProcessor, %{exporter: {Otel.OTLP.Logs.LogRecordExporter, %{}}}}
    ]
  end

  # ====== Propagator ======

  @doc """
  Returns the hardcoded global TextMap propagator —
  `Composite[TraceContext, Baggage]`, the OTel spec default
  per `sdk-environment-variables.md` L118
  (`OTEL_PROPAGATORS` default `"tracecontext,baggage"`) and
  `context/api-propagators.md` L329-331.

  Not configurable per minikube-style scope. The
  `:propagators` Application-env keyword is no longer read,
  and `OTEL_PROPAGATORS` env var is no longer parsed. Power
  users wanting B3 / Jaeger / X-Ray propagators should use
  `opentelemetry-erlang`.
  """
  @spec propagator() :: {module(), [module()]}
  def propagator do
    {Otel.API.Propagator.TextMap.Composite,
     [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]}
  end
end
