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

  ## No per-pillar overrides

  Per-pillar processors / readers / limits / filters are
  hardcoded to OTel spec defaults — there is no
  `config :otel, trace: [...]` knob. Power users wanting custom
  processors, readers, span limits, or exemplar filters should
  use `opentelemetry-erlang`. Tests that exercise the relevant
  code paths bypass `Otel.SDK.Application` and start providers
  directly via `Otel.TestSupport.restart_with/1`.

  ## Public API

  | Function | Returns |
  |---|---|
  | `resource/0` | Resolved `%Otel.Resource{}` from top-level `:resource` map merged with SDK identity attrs |
  | `exporter/1` | `{module, config}` tuple for the given signal (`:trace` / `:metrics` / `:logs`) |
  | `trace/0` | TracerProvider config map (hardcoded defaults) |
  | `metrics/0` | MeterProvider config map (hardcoded defaults) |
  | `logs/0` | LoggerProvider config map (hardcoded defaults) |

  ## References

  - OTel Trace SDK: `opentelemetry-specification/specification/trace/sdk.md`
  - OTel Metrics SDK: `opentelemetry-specification/specification/metrics/sdk.md`
  - OTel Logs SDK: `opentelemetry-specification/specification/logs/sdk.md`
  """

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

  @doc """
  Returns the TracerProvider config map. Processors and span
  limits are hardcoded to spec defaults; the resource and
  exporter map flow through from the top-level `:resource` and
  `:exporter` keys.
  """
  @spec trace() :: map()
  def trace do
    %{
      resource: resource(),
      processors: [{Otel.Trace.SpanProcessor, %{exporter: exporter(:trace)}}],
      span_limits: %Otel.Trace.SpanLimits{}
    }
  end

  @doc """
  Returns the MeterProvider config map. Reader, intervals and
  exemplar filter are hardcoded to spec defaults
  (`metrics/sdk.md` L1450-L1453: `exportIntervalMillis` `60000`,
  `exportTimeoutMillis` `30000`; L1123: `:trace_based`); the
  resource and exporter map flow through from the top-level
  `:resource` and `:exporter` keys.
  """
  @spec metrics() :: map()
  def metrics do
    %{
      resource: resource(),
      readers: [
        {Otel.Metrics.MetricReader.PeriodicExporting,
         %{
           exporter: exporter(:metrics),
           export_interval_ms: 60_000,
           export_timeout_ms: 30_000
         }}
      ],
      exemplar_filter: :trace_based
    }
  end

  @doc """
  Returns the LoggerProvider config map. Processors and log
  record limits are hardcoded to spec defaults; the resource
  and exporter map flow through from the top-level `:resource`
  and `:exporter` keys.
  """
  @spec logs() :: map()
  def logs do
    %{
      resource: resource(),
      processors: [{Otel.Logs.LogRecordProcessor, %{exporter: exporter(:logs)}}],
      log_record_limits: %Otel.Logs.LogRecordLimits{}
    }
  end
end
