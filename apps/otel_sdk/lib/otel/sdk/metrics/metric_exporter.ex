defmodule Otel.SDK.Metrics.MetricExporter do
  @moduledoc """
  Behaviour for push metric exporters.

  Exporters receive batches of collected metrics and transmit them
  to a backend. Export calls are serialized by the MetricReader.
  """

  @type state :: term()

  @callback init(config :: term()) :: {:ok, state()} | :ignore

  @callback export(
              metrics :: [Otel.SDK.Metrics.MetricReader.metric()],
              state :: state()
            ) :: :ok | :error

  @callback force_flush(state :: state()) :: :ok

  @callback shutdown(state :: state()) :: :ok
end
