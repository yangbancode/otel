defmodule Otel.Metrics.Aggregation.Sum do
  @moduledoc """
  Sum aggregation. Collects the arithmetic sum of measurements.

  Stores integer and float components separately for atomic updates.
  ETS entry format: `{key, int_value, float_value, start_time}`.

  Cumulative-only — `collect/3` returns the running total since
  stream start. Delta temporality is not supported (minikube
  hardcodes cumulative; spec `metrics/sdk.md` L1290-L1297 default).
  """

  @int_pos 2

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
    :ets.insert_new(metrics_tab, default)
    cas_add_float(metrics_tab, key, value)
  end

  @spec cas_add_float(metrics_tab :: :ets.table(), key :: term(), value :: float()) :: :ok
  defp cas_add_float(metrics_tab, key, value) do
    [{^key, _int_val, old_float, _start}] = :ets.lookup(metrics_tab, key)
    :ets.update_element(metrics_tab, key, [{3, old_float + value}])
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
        {{stream_name, :"$1"}, :"$2", :"$3", :"$4"},
        [],
        [{{:"$1", :"$2", :"$3", :"$4"}}]
      }
    ]

    metrics_tab
    |> :ets.select(match_spec)
    |> Enum.map(fn {attributes, int_value, float_value, start_time} ->
      %{
        attributes: attributes,
        value: int_value + float_value,
        start_time: start_time,
        time: now
      }
    end)
  end
end
