defmodule Otel.SDK.Metrics.Aggregation.Sum do
  @moduledoc """
  Sum aggregation. Collects the arithmetic sum of measurements.

  Stores integer and float components separately for atomic updates.
  ETS entry format: `{key, int_value, float_value, start_time}`.
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
    [{^key, int_val, old_float, start}] = :ets.lookup(metrics_tab, key)
    :ets.update_element(metrics_tab, key, [{3, old_float + value}])
    _ = {int_val, start}
    :ok
  end

  @impl true
  @spec collect(
          metrics_tab :: :ets.table(),
          stream_key :: {String.t(), Otel.API.InstrumentationScope.t()},
          opts :: map()
        ) :: [Otel.SDK.Metrics.Aggregation.datapoint()]
  def collect(metrics_tab, {stream_name, scope}, _opts) do
    now = System.system_time(:nanosecond)

    match_spec = [
      {
        {{stream_name, scope, :"$1"}, :"$2", :"$3", :"$4"},
        [],
        [{{:"$1", :"$2", :"$3", :"$4"}}]
      }
    ]

    :ets.select(metrics_tab, match_spec)
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
