defmodule Otel.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    # Six per-table `XxxStorage` GenServers own the metrics ETS
    # tables; they must start before `MetricReader.PeriodicExporting`
    # since the reader reads `Otel.Metrics.meter_config/0`
    # in its init. `Otel.Trace` and `Otel.Logs` hold no boot-time
    # state — `Otel.Resource.build/0` reads `RELEASE_NAME`/`RELEASE_VSN`
    # OS env vars on every call (no Mix Config knob for resource).
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
