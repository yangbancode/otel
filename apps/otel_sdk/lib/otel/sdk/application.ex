defmodule Otel.SDK.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    Otel.API.Trace.Span.set_module(Otel.SDK.Trace.Span)

    children = [
      Otel.SDK.Trace.SpanStorage,
      {Otel.SDK.Trace.TracerProvider, [name: Otel.SDK.Trace.TracerProvider]},
      {Otel.SDK.Metrics.MeterProvider, [name: Otel.SDK.Metrics.MeterProvider]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.SDK.Supervisor)
  end
end
