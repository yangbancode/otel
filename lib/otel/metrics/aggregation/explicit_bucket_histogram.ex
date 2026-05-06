defmodule Otel.Metrics.Aggregation.ExplicitBucketHistogram do
  @moduledoc """
  Explicit bucket histogram aggregation.

  Uses `:counters` for thread-safe bucket increments and
  `ets:update_counter` / `ets:select_replace` for atomic
  count, sum, min, and max updates.

  ETS entry format:
  `{key, counters_ref, min, max, sum, count, start_time}`.

  Cumulative-only — `collect/3` returns running totals since
  stream start. Delta temporality is not supported (minikube
  hardcodes cumulative; spec `metrics/sdk.md` L1290-L1297 default).

  ## Configuration parameters

  `Otel.Metrics.Meter.register_instrument/4` resolves
  `:boundaries` from the instrument's advisory
  `:explicit_bucket_boundaries` (when present).

  | Key | Default | Description |
  |---|---|---|
  | `:boundaries` | `@default_boundaries` (15 OTel-default buckets) | Bucket boundaries per `metrics/sdk.md` L660-L661 |

  Spec `metrics/sdk.md` L662 also lists a `RecordMinMax` Stream
  config knob; minikube has no Views so it is permanently on
  and not exposed here. The encoder's `min: nil` / `max: nil`
  path still exists for the brief concurrent-collect window
  before the first measurement updates the ETS row.
  """

  @default_boundaries [0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10_000]

  @count_pos 6
  @sum_pos 5

  @spec default_boundaries() :: [number()]
  def default_boundaries, do: @default_boundaries

  @spec aggregate(
          metrics_tab :: :ets.table(),
          key :: term(),
          value :: number(),
          opts :: map()
        ) :: :ok
  def aggregate(metrics_tab, key, value, opts) do
    boundaries = Map.get(opts, :boundaries, @default_boundaries)

    case :ets.lookup(metrics_tab, key) do
      [{^key, counters_ref, _min, _max, _sum, _count, _start}] ->
        bucket_idx = find_bucket(value, boundaries)
        :counters.add(counters_ref, bucket_idx, 1)
        :ets.update_counter(metrics_tab, key, [{@count_pos, 1}])
        update_sum(metrics_tab, key, value)
        update_min(metrics_tab, key, value)
        update_max(metrics_tab, key, value)
        :ok

      [] ->
        init_and_aggregate(metrics_tab, key, value, boundaries)
    end
  end

  @spec collect(
          metrics_tab :: :ets.table(),
          stream_key :: String.t(),
          opts :: map()
        ) :: [Otel.Metrics.Aggregation.datapoint()]
  def collect(metrics_tab, stream_name, opts) do
    boundaries = Map.get(opts, :boundaries, @default_boundaries)
    now = System.system_time(:nanosecond)
    num_buckets = length(boundaries) + 1

    match_spec = [
      {
        {{stream_name, :"$1"}, :"$2", :"$3", :"$4", :"$5", :"$6", :"$7"},
        [],
        [{{:"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7"}}]
      }
    ]

    metrics_tab
    |> :ets.select(match_spec)
    |> Enum.map(fn {attributes, counters_ref, min, max, sum, count, start_time} ->
      bucket_counts = read_bucket_counts(counters_ref, num_buckets)

      %{
        attributes: attributes,
        value: %{
          boundaries: boundaries,
          bucket_counts: bucket_counts,
          min: normalize_min(min),
          max: normalize_max(max),
          sum: sum,
          count: count
        },
        start_time: start_time,
        time: now
      }
    end)
  end

  @spec init_and_aggregate(
          metrics_tab :: :ets.table(),
          key :: term(),
          value :: number(),
          boundaries :: [number()]
        ) :: :ok
  defp init_and_aggregate(metrics_tab, key, value, boundaries) do
    num_buckets = length(boundaries) + 1
    counters_ref = :counters.new(num_buckets, [:write_concurrency])
    bucket_idx = find_bucket(value, boundaries)
    :counters.add(counters_ref, bucket_idx, 1)
    start_time = System.system_time(:nanosecond)

    case :ets.insert_new(metrics_tab, {key, counters_ref, :unset, :unset, 0, 0, start_time}) do
      true ->
        :ets.update_counter(metrics_tab, key, [{@count_pos, 1}])
        :ets.update_element(metrics_tab, key, [{@sum_pos, value}])
        update_min(metrics_tab, key, value)
        update_max(metrics_tab, key, value)
        :ok

      false ->
        aggregate(metrics_tab, key, value, %{boundaries: boundaries})
    end
  end

  @spec find_bucket(value :: number(), boundaries :: [number()]) :: pos_integer()
  defp find_bucket(value, boundaries) do
    find_bucket(value, boundaries, 1)
  end

  @spec find_bucket(value :: number(), boundaries :: [number()], index :: pos_integer()) ::
          pos_integer()
  defp find_bucket(_value, [], index), do: index

  defp find_bucket(value, [boundary | rest], index) do
    if value <= boundary do
      index
    else
      find_bucket(value, rest, index + 1)
    end
  end

  @spec update_sum(metrics_tab :: :ets.table(), key :: term(), value :: number()) :: :ok
  defp update_sum(metrics_tab, key, value) when is_integer(value) do
    :ets.update_counter(metrics_tab, key, [{@sum_pos, value}])
    :ok
  end

  defp update_sum(metrics_tab, key, value) when is_float(value) do
    [{^key, _, _, _, old_sum, _, _}] = :ets.lookup(metrics_tab, key)
    :ets.update_element(metrics_tab, key, [{@sum_pos, old_sum + value}])
    :ok
  end

  @spec update_min(metrics_tab :: :ets.table(), key :: term(), value :: number()) :: :ok
  defp update_min(metrics_tab, key, value) do
    [{^key, _, current_min, _, _, _, _}] = :ets.lookup(metrics_tab, key)

    if current_min == :unset or value < current_min do
      :ets.update_element(metrics_tab, key, [{3, value}])
    end

    :ok
  end

  @spec update_max(metrics_tab :: :ets.table(), key :: term(), value :: number()) :: :ok
  defp update_max(metrics_tab, key, value) do
    [{^key, _, _, current_max, _, _, _}] = :ets.lookup(metrics_tab, key)

    if current_max == :unset or value > current_max do
      :ets.update_element(metrics_tab, key, [{4, value}])
    end

    :ok
  end

  @spec read_bucket_counts(counters_ref :: :counters.counters_ref(), num_buckets :: pos_integer()) ::
          [non_neg_integer()]
  defp read_bucket_counts(counters_ref, num_buckets) do
    Enum.map(1..num_buckets, fn i -> :counters.get(counters_ref, i) end)
  end

  @spec normalize_min(value :: number() | :unset) :: number() | nil
  defp normalize_min(:unset), do: nil
  defp normalize_min(value), do: value

  @spec normalize_max(value :: number() | :unset) :: number() | nil
  defp normalize_max(:unset), do: nil
  defp normalize_max(value), do: value
end
