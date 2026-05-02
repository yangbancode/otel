defmodule Otel.SDK.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    # Seed `:persistent_term` for the three Provider modules
    # (resource, span_limits, exemplar_filter, log_record_limits,
    # ETS table refs). Must run before `MetricReader.PeriodicExporting`
    # starts, since the reader reads `MeterProvider.reader_meter_config/0`
    # in its init.
    Otel.Trace.TracerProvider.init()
    Otel.Metrics.MeterProvider.init()
    Otel.Logs.LoggerProvider.init()

    children = [
      Otel.Trace.SpanStorage,
      Otel.Trace.SpanProcessor,
      Otel.Metrics.MetricReader.PeriodicExporting,
      Otel.Logs.LogRecordProcessor
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.SDK.Supervisor)
  end
end
