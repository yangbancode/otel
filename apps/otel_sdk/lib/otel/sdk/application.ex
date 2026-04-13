defmodule Otel.SDK.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(type :: Application.start_type(), args :: term()) :: {:ok, pid()}
  def start(_type, _args) do
    children = [
      Otel.SDK.Trace.SpanStorage
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Otel.SDK.Supervisor)
  end
end
