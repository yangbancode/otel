defmodule Otel.SDK.Application do
  @moduledoc false

  use Application

  @default_config %{
    sampler:
      {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}},
    processors: [],
    id_generator: Otel.SDK.Trace.IdGenerator.Default,
    resource: %{},
    span_limits: %Otel.SDK.Trace.SpanLimits{}
  }

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    user_config =
      :otel_sdk
      |> Application.get_all_env()
      |> Map.new()

    config = Map.merge(@default_config, user_config)

    Otel.API.Trace.Span.set_span_module(Otel.SDK.Trace.SpanOps)

    children = [
      Otel.SDK.Trace.SpanStorage,
      {Otel.SDK.Trace.TracerProvider, [config: config, name: Otel.SDK.Trace.TracerProvider]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.SDK.Supervisor)
  end
end
