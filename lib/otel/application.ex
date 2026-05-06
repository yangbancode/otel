defmodule Otel.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    # Four per-table `XxxStorage` GenServers own the metrics ETS
    # tables; they must start before `MetricExporter` since the
    # exporter calls `Otel.Metrics.meter_config/0` in its
    # `do_export/0`. `Otel.Trace` and `Otel.Logs` hold no
    # boot-time state — `Otel.Resource.new/0` reads
    # `RELEASE_NAME`/`RELEASE_VSN` OS env vars on every call (no
    # Mix Config knob for resource).
    children = [
      Otel.Trace.SpanStorage,
      Otel.Logs.LogRecordStorage,
      Otel.Metrics.InstrumentsStorage,
      Otel.Metrics.StreamsStorage,
      Otel.Metrics.MetricsStorage,
      Otel.Metrics.ExemplarsStorage,
      Otel.Trace.SpanExporter,
      Otel.Logs.LogRecordExporter,
      Otel.Metrics.MetricExporter
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.Supervisor)
  end
end
