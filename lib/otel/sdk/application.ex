defmodule Otel.SDK.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    Otel.API.Propagator.TextMap.set_propagator(Otel.SDK.Config.propagator())

    children = [
      Otel.Trace.SpanStorage,
      {Otel.Trace.TracerProvider, [config: Otel.SDK.Config.trace()]},
      {Otel.SDK.Metrics.MeterProvider, [config: Otel.SDK.Config.metrics()]},
      {Otel.SDK.Logs.LoggerProvider, [config: Otel.SDK.Config.logs()]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.SDK.Supervisor)
  end
end
