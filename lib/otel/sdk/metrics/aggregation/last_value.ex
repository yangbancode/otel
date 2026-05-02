defmodule Otel.SDK.Metrics.Aggregation.LastValue do
  @moduledoc """
  Last value aggregation. Keeps the most recent measurement.

  ETS entry format: `{key, value, timestamp, start_time}`.
  Uses `ets:insert` (overwrite) — last writer wins, which is the
  correct semantic for gauges.

  Gauge data points have no aggregation temporality.
  """

  @behaviour Otel.SDK.Metrics.Aggregation

  @impl true
  @spec aggregate(
          metrics_tab :: :ets.table(),
          key :: term(),
          value :: number(),
          opts :: map()
        ) :: :ok
  def aggregate(metrics_tab, key, value, _opts) do
    now = System.system_time(:nanosecond)

    case :ets.insert_new(metrics_tab, {key, value, now, now}) do
      true ->
        :ok

      false ->
        :ets.update_element(metrics_tab, key, [{2, value}, {3, now}])
        :ok
    end
  end

  @impl true
  @spec collect(
          metrics_tab :: :ets.table(),
          stream_key :: {String.t(), Otel.InstrumentationScope.t()},
          opts :: map()
        ) :: [Otel.SDK.Metrics.Aggregation.datapoint()]
  def collect(metrics_tab, {stream_name, scope}, opts) do
    reader_id = Map.get(opts, :reader_id)
    now = System.system_time(:nanosecond)

    match_spec = [
      {
        {{stream_name, scope, reader_id, :"$1"}, :"$2", :"$3", :"$4"},
        [],
        [{{:"$1", :"$2", :"$3", :"$4"}}]
      }
    ]

    :ets.select(metrics_tab, match_spec)
    |> Enum.map(fn {attributes, value, _timestamp, start_time} ->
      %{
        attributes: attributes,
        value: value,
        start_time: start_time,
        time: now
      }
    end)
  end
end
