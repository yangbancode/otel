defmodule Otel.SDK.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    children = [
      Otel.Trace.SpanStorage,
      {Otel.Trace.TracerProvider, [config: Otel.SDK.Config.trace()]},
      {Otel.Metrics.MeterProvider, [config: Otel.SDK.Config.metrics()]},
      {Otel.Logs.LoggerProvider, [config: Otel.SDK.Config.logs()]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.SDK.Supervisor)
  end
end
