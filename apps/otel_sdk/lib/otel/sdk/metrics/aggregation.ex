defmodule Otel.SDK.Metrics.Aggregation do
  @moduledoc """
  Aggregation behaviour and default instrument-to-aggregation mapping.
  """

  @type datapoint :: %{
          attributes: map(),
          value: term(),
          start_time: integer(),
          time: integer()
        }

  @callback aggregate(
              metrics_tab :: :ets.table(),
              key :: term(),
              value :: number(),
              opts :: map()
            ) :: :ok

  @callback collect(
              metrics_tab :: :ets.table(),
              stream_key :: term(),
              opts :: map()
            ) :: [datapoint()]

  @spec default_module(kind :: Otel.API.Metrics.Instrument.kind()) :: module()
  def default_module(:counter), do: Otel.SDK.Metrics.Aggregation.Sum
  def default_module(:updown_counter), do: Otel.SDK.Metrics.Aggregation.Sum
  def default_module(:histogram), do: Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram
  def default_module(:gauge), do: Otel.SDK.Metrics.Aggregation.LastValue
  def default_module(:observable_counter), do: Otel.SDK.Metrics.Aggregation.Sum
  def default_module(:observable_gauge), do: Otel.SDK.Metrics.Aggregation.LastValue
  def default_module(:observable_updown_counter), do: Otel.SDK.Metrics.Aggregation.Sum
end
