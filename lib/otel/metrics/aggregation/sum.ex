defmodule Otel.Metrics.Aggregation.Sum do
  @moduledoc """
  Sum aggregation. Collects the arithmetic sum of measurements.

  Stores integer and float components separately for atomic updates.
  ETS entry format:
  `{key, int_value, float_value, start_time, reservoir_state}`.

  The fifth slot holds the exemplar reservoir state
  (`Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize`). Reservoir
  state lives alongside the aggregation cell so a single ETS row
  carries everything `collect/3` needs to emit a datapoint with
  exemplars — there is no separate `ExemplarsStorage` table.

  Cumulative-only — `collect/3` returns the running total since
  stream start. Delta temporality is not supported (minikube
  hardcodes cumulative; spec `metrics/sdk.md` L1290-L1297 default).
  """

  @int_pos 2
  @reservoir_pos 5

  @reservoir_module Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize
  @reservoir_opts %{size: 1}

  @spec aggregate(
          metrics_tab :: :ets.table(),
          key :: term(),
          value :: number(),
          opts :: map()
        ) :: :ok
  def aggregate(metrics_tab, key, value, _opts) when is_integer(value) do
    :ets.update_counter(
      metrics_tab,
      key,
      [{@int_pos, value}],
      default_row(key)
    )

    :ok
  end

  def aggregate(metrics_tab, key, value, _opts) when is_float(value) do
    :ets.insert_new(metrics_tab, default_row(key))
    cas_add_float(metrics_tab, key, value)
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
    [{^key, _int, _float, _start, reservoir_state}] = :ets.lookup(metrics_tab, key)
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
    |> Enum.map(fn {attributes, int_value, float_value, start_time, reservoir_state} ->
      {exemplars, new_state} = @reservoir_module.collect(reservoir_state)
      :ets.update_element(metrics_tab, {stream_name, attributes}, [{@reservoir_pos, new_state}])

      %{
        attributes: attributes,
        value: int_value + float_value,
        start_time: start_time,
        time: now,
        exemplars: exemplars
      }
    end)
  end

  @spec default_row(key :: term()) ::
          {term(), integer(), float(), non_neg_integer(), term()}
  defp default_row(key) do
    {key, 0, 0.0, System.system_time(:nanosecond), @reservoir_module.new(@reservoir_opts)}
  end

  @spec cas_add_float(metrics_tab :: :ets.table(), key :: term(), value :: float()) :: :ok
  defp cas_add_float(metrics_tab, key, value) do
    [{^key, _int_val, old_float, _start, _reservoir}] = :ets.lookup(metrics_tab, key)
    :ets.update_element(metrics_tab, key, [{3, old_float + value}])
    :ok
  end
end
