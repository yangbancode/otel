defmodule Otel.SDK.Config do
  @moduledoc """
  Composes provider configuration from the user's Application env.

  ## Configuration UX

  Two top-level keys cover the entire user-facing surface:

  ```elixir
  # config/runtime.exs
  config :otel,
    resource: %{"service.name" => "my_app"},
    exporter: %{endpoint: "http://localhost:4318"}
  ```

  | Key | Type | Default |
  |---|---|---|
  | `:resource` | `%{String.t() => term()}` | `%{"service.name" => "unknown_service"}` |
  | `:exporter` | `%{endpoint: String.t(), headers: map(), ssl_options: keyword(), ...}` | `%{}` (uses exporter defaults) |

  Bridge OS env vars from `runtime.exs` (Phoenix `PHX_SERVER` pattern):

      # config/runtime.exs
      import Config

      config :otel,
        resource: %{
          "service.name" => System.get_env("OTEL_SERVICE_NAME") || "my_app"
        },
        exporter: %{
          endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") || "http://localhost:4318"
        }

  To disable telemetry (test environments, CI, etc.), exclude
  `:otel` from your application's `extra_applications` rather
  than leaving it loaded — there is no runtime kill switch.

  ## Advanced overrides (test / power-user only)

  Per-pillar keys (`trace:`, `metrics:`, `logs:`) accept the
  underlying processor / reader / limits structures. These are
  retained for tests that exercise specific code paths and
  power users who need full control; they bypass the simple
  surface above.

  ```elixir
  config :otel,
    trace: [
      processors: [{MyApp.CustomProcessor, %{...}}],
      span_limits: %{attribute_count_limit: 32}
    ],
    metrics: [
      readers: [{MyApp.CustomReader, %{...}}],
      exemplar_filter: :always_on
    ],
    logs: [
      processors: [{MyApp.CustomProcessor, %{...}}],
      log_record_limits: %{attribute_count_limit: 32}
    ]
  ```

  When a per-pillar override is set, the matching top-level
  key is bypassed for that pillar. Per-pillar `:resource`
  expects an `%Otel.SDK.Resource{}` struct, not a map.

  ## Public API

  | Function | Returns |
  |---|---|
  | `resource/0` | Resolved `%Otel.SDK.Resource{}` from top-level `:resource` map merged with SDK identity attrs |
  | `exporter/1` | `{module, config}` tuple for the given signal (`:trace` / `:metrics` / `:logs`) |
  | `trace/0` | TracerProvider config map |
  | `metrics/0` | MeterProvider config map |
  | `logs/0` | LoggerProvider config map |
  | `propagator/0` | Global TextMap propagator (`{Composite, [TraceContext, Baggage]}`) |

  ## References

  - OTel Trace SDK: `opentelemetry-specification/specification/trace/sdk.md`
  - OTel Metrics SDK: `opentelemetry-specification/specification/metrics/sdk.md`
  - OTel Logs SDK: `opentelemetry-specification/specification/logs/sdk.md`
  """

  require Logger

  @doc """
  Resolves the user-configured Resource by merging
  `config :otel, resource: %{...}` (a map of attribute pairs)
  on top of the SDK identity attributes
  (`telemetry.sdk.{name,language,version}` + the
  `service.name = "unknown_service"` fallback).

  User attributes take precedence on key conflicts. The
  `service.name` fallback is only applied when no value is
  provided.
  """
  @spec resource() :: Otel.SDK.Resource.t()
  def resource do
    user_attrs = Application.get_env(:otel, :resource, %{})
    Otel.SDK.Resource.merge(Otel.SDK.Resource.default(), Otel.SDK.Resource.create(user_attrs))
  end

  @doc """
  Returns the OTLP/HTTP exporter `{module, config}` tuple for
  the given signal. The same `config :otel, exporter: %{...}`
  map is forwarded verbatim to all three exporters.

  Common keys: `:endpoint`, `:headers`, `:ssl_options`. See
  the exporter modules for the full list.
  """
  @spec exporter(signal :: :trace | :metrics | :logs) :: {module(), map()}
  def exporter(:trace), do: {Otel.OTLP.Trace.SpanExporter, exporter_config()}
  def exporter(:metrics), do: {Otel.OTLP.Metrics.MetricExporter, exporter_config()}
  def exporter(:logs), do: {Otel.OTLP.Logs.LogRecordExporter, exporter_config()}

  @spec exporter_config() :: map()
  defp exporter_config do
    Application.get_env(:otel, :exporter, %{})
  end

  # ====== Trace ======

  @doc """
  Builds the TracerProvider config map by composing top-level
  `:resource` / `:exporter` and the per-pillar advanced
  overrides on `config :otel, trace: [...]`.
  """
  @spec trace() :: map()
  def trace do
    pillar = Application.get_env(:otel, :trace, [])

    %{
      resource: Keyword.get(pillar, :resource, resource()),
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
    [{Otel.SDK.Trace.SpanProcessor, %{exporter: exporter(:trace)}}]
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
      resource: Keyword.get(pillar, :resource, resource()),
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
  @spec default_metrics_readers(pillar :: keyword()) ::
          [{module(), Otel.SDK.Metrics.MetricReader.config()}]
  defp default_metrics_readers(_pillar) do
    [
      {Otel.SDK.Metrics.MetricReader.PeriodicExporting,
       %{
         exporter: exporter(:metrics),
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
      resource: Keyword.get(pillar, :resource, resource()),
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
    [{Otel.SDK.Logs.LogRecordProcessor, %{exporter: exporter(:logs)}}]
  end

  # ====== Propagator ======

  @doc """
  Returns the hardcoded global TextMap propagator —
  `Composite[TraceContext, Baggage]`, the OTel spec default
  per `sdk-environment-variables.md` L118
  (`OTEL_PROPAGATORS` default `"tracecontext,baggage"`) and
  `context/api-propagators.md` L329-331.

  Not configurable per minikube-style scope. Power users
  wanting B3 / Jaeger / X-Ray propagators should use
  `opentelemetry-erlang`.
  """
  @spec propagator() :: {module(), [module()]}
  def propagator do
    {Otel.API.Propagator.TextMap.Composite,
     [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]}
  end
end
