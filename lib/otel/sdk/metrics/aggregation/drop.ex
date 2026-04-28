defmodule Otel.SDK.Metrics.Aggregation.Drop do
  @moduledoc """
  Drop aggregation. Ignores all measurements.
  """

  @behaviour Otel.SDK.Metrics.Aggregation

  @impl true
  @spec aggregate(
          metrics_tab :: :ets.table(),
          key :: term(),
          value :: number(),
          opts :: map()
        ) :: :ok
  def aggregate(_metrics_tab, _key, _value, _opts), do: :ok

  @impl true
  @spec collect(
          metrics_tab :: :ets.table(),
          stream_key :: term(),
          opts :: map()
        ) :: [Otel.SDK.Metrics.Aggregation.datapoint()]
  def collect(_metrics_tab, _stream_key, _opts), do: []
end
