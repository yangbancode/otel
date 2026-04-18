defmodule Otel.SDK.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    app_config =
      :otel_sdk
      |> Application.get_all_env()
      |> Map.new()

    config = Otel.SDK.Configuration.merge(app_config)

    Otel.API.Trace.Span.set_span_module(Otel.SDK.Trace.Span)

    children = [
      Otel.SDK.Trace.SpanStorage,
      {Otel.SDK.Trace.TracerProvider, [config: config, name: Otel.SDK.Trace.TracerProvider]},
      {Otel.SDK.Metrics.MeterProvider, [config: config, name: Otel.SDK.Metrics.MeterProvider]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.SDK.Supervisor)
  end
end
