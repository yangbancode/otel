defmodule Otel.SDK.Metrics.Aggregation.Sum do
  @moduledoc """
  Sum aggregation. Collects the arithmetic sum of measurements.

  Stores integer and float components separately for atomic updates.
  ETS entry format: `{key, int_value, float_value, start_time}`.

  Supports Cumulative and Delta temporality. For Delta, values are
  atomically read and subtracted during collection.
  """

  @behaviour Otel.SDK.Metrics.Aggregation

  @int_pos 2

  @impl true
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
      {key, 0, 0.0, System.system_time(:nanosecond)}
    )

    :ok
  end

  def aggregate(metrics_tab, key, value, _opts) when is_float(value) do
    default = {key, 0, 0.0, System.system_time(:nanosecond)}

    case :ets.insert_new(metrics_tab, default) do
      true -> :ok
      false -> :ok
    end

    cas_add_float(metrics_tab, key, value)
  end

  @spec cas_add_float(metrics_tab :: :ets.table(), key :: term(), value :: float()) :: :ok
  defp cas_add_float(metrics_tab, key, value) do
    [{^key, _int_val, old_float, _start}] = :ets.lookup(metrics_tab, key)
    :ets.update_element(metrics_tab, key, [{3, old_float + value}])
    :ok
  end

  @impl true
  @spec collect(
          metrics_tab :: :ets.table(),
          stream_key :: {String.t(), Otel.API.InstrumentationScope.t()},
          opts :: map()
        ) :: [Otel.SDK.Metrics.Aggregation.datapoint()]
  def collect(metrics_tab, {stream_name, scope}, opts) do
    reader_id = Map.get(opts, :reader_id)
    temporality = Map.get(opts, :temporality, :cumulative)
    now = System.system_time(:nanosecond)

    match_spec = [
      {
        {{stream_name, scope, reader_id, :"$1"}, :"$2", :"$3", :"$4"},
        [],
        [{{:"$1", :"$2", :"$3", :"$4"}}]
      }
    ]

    entries = :ets.select(metrics_tab, match_spec)

    case temporality do
      :cumulative ->
        collect_cumulative(entries, now)

      :delta ->
        collect_delta(metrics_tab, entries, stream_name, scope, reader_id, now)
    end
  end

  @spec collect_cumulative(
          entries :: [{[Otel.API.Common.Attribute.t()], integer(), float(), integer()}],
          now :: integer()
        ) :: [Otel.SDK.Metrics.Aggregation.datapoint()]
  defp collect_cumulative(entries, now) do
    Enum.map(entries, fn {attributes, int_value, float_value, start_time} ->
      %{
        attributes: attributes,
        value: int_value + float_value,
        start_time: start_time,
        time: now
      }
    end)
  end

  @spec collect_delta(
          metrics_tab :: :ets.table(),
          entries :: [{[Otel.API.Common.Attribute.t()], integer(), float(), integer()}],
          stream_name :: String.t(),
          scope :: Otel.API.InstrumentationScope.t(),
          reader_id :: reference() | nil,
          now :: integer()
        ) :: [Otel.SDK.Metrics.Aggregation.datapoint()]
  defp collect_delta(metrics_tab, entries, stream_name, scope, reader_id, now) do
    entries
    |> Enum.map(fn {attributes, int_value, float_value, start_time} ->
      key = {stream_name, scope, reader_id, attributes}
      reset_sum(metrics_tab, key, int_value, float_value, now)

      %{
        attributes: attributes,
        value: int_value + float_value,
        start_time: start_time,
        time: now
      }
    end)
    |> Enum.reject(fn dp -> dp.value == 0 end)
  end

  @spec reset_sum(
          metrics_tab :: :ets.table(),
          key :: term(),
          int_value :: integer(),
          float_value :: float(),
          now :: integer()
        ) :: :ok
  defp reset_sum(metrics_tab, key, int_value, float_value, now) do
    :ets.update_counter(metrics_tab, key, [{@int_pos, -int_value}])
    cas_subtract_float(metrics_tab, key, float_value)
    :ets.update_element(metrics_tab, key, [{4, now}])
    :ok
  end

  @spec cas_subtract_float(metrics_tab :: :ets.table(), key :: term(), value :: float()) :: :ok
  defp cas_subtract_float(_metrics_tab, _key, value) when value == 0.0, do: :ok

  defp cas_subtract_float(metrics_tab, key, value) do
    [{^key, _int_val, old_float, _start}] = :ets.lookup(metrics_tab, key)
    :ets.update_element(metrics_tab, key, [{3, old_float - value}])
    :ok
  end
end
