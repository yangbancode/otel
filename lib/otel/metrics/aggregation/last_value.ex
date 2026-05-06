defmodule Otel.Metrics.Aggregation.LastValue do
  @moduledoc """
  Last value aggregation. Keeps the most recent measurement.

  ETS entry format:
  `{key, value, timestamp, start_time, reservoir_state}`.
  Uses `ets:insert_new` + `ets:update_element` (overwrite) —
  last writer wins, which is the correct semantic for gauges.

  The fifth slot holds the exemplar reservoir state
  (`Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize`) so a single
  ETS row carries everything `collect/3` needs.

  Gauge data points have no aggregation temporality.
  """

  @reservoir_pos 5

  @reservoir_module Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize
  @reservoir_opts %{size: 1}

  @spec aggregate(
          metrics_tab :: :ets.table(),
          key :: term(),
          value :: number(),
          opts :: map()
        ) :: :ok
  def aggregate(metrics_tab, key, value, _opts) do
    now = System.system_time(:nanosecond)

    case :ets.insert_new(
           metrics_tab,
           {key, value, now, now, @reservoir_module.new(@reservoir_opts)}
         ) do
      true ->
        :ok

      false ->
        :ets.update_element(metrics_tab, key, [{2, value}, {3, now}])
        :ok
    end
  end

  @spec offer_exemplar(
          metrics_tab :: :ets.table(),
          key :: term(),
          value :: number(),
          time :: non_neg_integer(),
          filtered_attrs :: %{String.t() => term()},
          ctx :: Otel.Ctx.t()
        ) :: :ok
  def offer_exemplar(metrics_tab, key, value, time, filtered_attrs, ctx) do
    [{^key, _value, _ts, _start, reservoir_state}] = :ets.lookup(metrics_tab, key)
    new_state = @reservoir_module.offer(reservoir_state, value, time, filtered_attrs, ctx)
    :ets.update_element(metrics_tab, key, [{@reservoir_pos, new_state}])
    :ok
  end

  @spec collect(
          metrics_tab :: :ets.table(),
          stream_key :: String.t(),
          opts :: map()
        ) :: [Otel.Metrics.Aggregation.datapoint()]
  def collect(metrics_tab, stream_name, _opts) do
    now = System.system_time(:nanosecond)

    match_spec = [
      {
        {{stream_name, :"$1"}, :"$2", :"$3", :"$4", :"$5"},
        [],
        [{{:"$1", :"$2", :"$3", :"$4", :"$5"}}]
      }
    ]

    metrics_tab
    |> :ets.select(match_spec)
    |> Enum.map(fn {attributes, value, _ts, start_time, reservoir_state} ->
      {exemplars, new_state} = @reservoir_module.collect(reservoir_state)
      :ets.update_element(metrics_tab, {stream_name, attributes}, [{@reservoir_pos, new_state}])

      %{
        attributes: attributes,
        value: value,
        start_time: start_time,
        time: now,
        exemplars: exemplars
      }
    end)
  end
end
