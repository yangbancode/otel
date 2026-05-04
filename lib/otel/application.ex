defmodule Otel.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    # Six per-table `XxxStorage` GenServers own the metrics ETS
    # tables; they must start before `MetricReader.PeriodicExporting`
    # since the reader reads `Otel.Metrics.reader_meter_config/0`
    # in its init. `Otel.Trace` and `Otel.Logs` hold no boot-time
    # state — the only user-tunable knob is the `:resource`
    # Application env, read via `Otel.Resource.from_app_env/0`
    # on demand.
    children = [
      Otel.Trace.SpanStorage,
      Otel.Metrics.InstrumentsStorage,
      Otel.Metrics.StreamsStorage,
      Otel.Metrics.MetricsStorage,
      Otel.Metrics.CallbacksStorage,
      Otel.Metrics.ExemplarsStorage,
      Otel.Metrics.ObservedAttrsStorage,
      Otel.Trace.SpanProcessor,
      Otel.Metrics.MetricReader.PeriodicExporting,
      Otel.Logs.LogRecordProcessor
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.Supervisor)
  end
end
