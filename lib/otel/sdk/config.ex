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
      span_limits: %Otel.Trace.SpanLimits{attribute_count_limit: 32}
    ],
    metrics: [
      readers: [{MyApp.CustomReader, %{...}}],
      exemplar_filter: :always_on
    ],
    logs: [
      processors: [{MyApp.CustomProcessor, %{...}}],
      log_record_limits: %Otel.Logs.LogRecordLimits{attribute_count_limit: 32}
    ]
  ```

  When a per-pillar override is set, the matching top-level
  key is bypassed for that pillar. The struct-typed overrides
  (`:resource`, `:span_limits`, `:log_record_limits`) expect
  the corresponding struct verbatim — no map / keyword
  coercion.

  ## Public API

  | Function | Returns |
  |---|---|
  | `resource/0` | Resolved `%Otel.Resource{}` from top-level `:resource` map merged with SDK identity attrs |
  | `exporter/1` | `{module, config}` tuple for the given signal (`:trace` / `:metrics` / `:logs`) |
  | `trace/0` | TracerProvider config map |
  | `metrics/0` | MeterProvider config map |
  | `logs/0` | LoggerProvider config map |

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
  @spec resource() :: Otel.Resource.t()
  def resource do
    user_attrs = Application.get_env(:otel, :resource, %{})
    Otel.Resource.merge(Otel.Resource.default(), Otel.Resource.create(user_attrs))
  end

  @doc """
  Returns the OTLP/HTTP exporter `{module, config}` tuple for
  the given signal. The same `config :otel, exporter: %{...}`
  map is forwarded verbatim to all three exporters.

  Common keys: `:endpoint`, `:headers`, `:ssl_options`. See
  the exporter modules for the full list.
  """
  @spec exporter(signal :: :trace | :metrics | :logs) :: {module(), map()}
  def exporter(:trace), do: {Otel.Trace.SpanExporter, exporter_config()}
  def exporter(:metrics), do: {Otel.Metrics.MetricExporter, exporter_config()}
  def exporter(:logs), do: {Otel.Logs.LogRecordExporter, exporter_config()}

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
      span_limits: Keyword.get(pillar, :span_limits, %Otel.Trace.SpanLimits{})
    }
  end

  @spec build_trace_processors(pillar :: keyword()) ::
          [{module(), Otel.Trace.SpanProcessor.config()}]
  defp build_trace_processors(pillar) do
    case Keyword.get(pillar, :processors) do
      nil -> default_trace_processors(pillar)
      processors -> processors
    end
  end

  @spec default_trace_processors(pillar :: keyword()) ::
          [{module(), Otel.Trace.SpanProcessor.config()}]
  defp default_trace_processors(_pillar) do
    [{Otel.Trace.SpanProcessor, %{exporter: exporter(:trace)}}]
  end

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
      exemplar_filter: Keyword.get(pillar, :exemplar_filter, :trace_based)
    }
  end

  @spec build_metrics_readers(pillar :: keyword()) ::
          [{module(), Otel.Metrics.MetricReader.config()}]
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
          [{module(), Otel.Metrics.MetricReader.config()}]
  defp default_metrics_readers(_pillar) do
    [
      {Otel.Metrics.MetricReader.PeriodicExporting,
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
      log_record_limits: Keyword.get(pillar, :log_record_limits, %Otel.Logs.LogRecordLimits{})
    }
  end

  @spec build_logs_processors(pillar :: keyword()) ::
          [{module(), Otel.Logs.LogRecordProcessor.config()}]
  defp build_logs_processors(pillar) do
    case Keyword.get(pillar, :processors) do
      nil -> default_logs_processors(pillar)
      processors -> processors
    end
  end

  @spec default_logs_processors(pillar :: keyword()) ::
          [{module(), Otel.Logs.LogRecordProcessor.config()}]
  defp default_logs_processors(_pillar) do
    [{Otel.Logs.LogRecordProcessor, %{exporter: exporter(:logs)}}]
  end
end
