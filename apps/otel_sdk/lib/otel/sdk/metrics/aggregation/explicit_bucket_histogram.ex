defmodule Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram do
  @moduledoc """
  Explicit bucket histogram aggregation.

  Uses `:counters` for thread-safe bucket increments and
  `ets:update_counter` / `ets:select_replace` for atomic
  count, sum, min, and max updates.

  ETS entry format:
  `{key, counters_ref, min, max, sum, count, start_time}`.

  Supports both Cumulative and Delta temporality. For Delta,
  bucket counts, sum, and count are atomically read and reset;
  min and max are reset to `:unset`.
  """

  @behaviour Otel.SDK.Metrics.Aggregation

  @default_boundaries [0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10_000]

  @count_pos 6
  @sum_pos 5

  @spec default_boundaries() :: [number()]
  def default_boundaries, do: @default_boundaries

  @impl true
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
        update_count(metrics_tab, key)
        update_sum(metrics_tab, key, value)
        update_min(metrics_tab, key, value)
        update_max(metrics_tab, key, value)
        :ok

      [] ->
        init_and_aggregate(metrics_tab, key, value, boundaries)
    end
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
    boundaries = Map.get(opts, :boundaries, @default_boundaries)
    now = System.system_time(:nanosecond)

    match_spec = [
      {
        {{stream_name, scope, reader_id, :"$1"}, :"$2", :"$3", :"$4", :"$5", :"$6", :"$7"},
        [],
        [{{:"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7"}}]
      }
    ]

    entries = :ets.select(metrics_tab, match_spec)
    num_buckets = length(boundaries) + 1

    case temporality do
      :cumulative ->
        collect_cumulative(entries, boundaries, num_buckets, now)

      :delta ->
        collect_delta(
          metrics_tab,
          entries,
          stream_name,
          scope,
          reader_id,
          boundaries,
          num_buckets,
          now
        )
    end
  end

  @spec collect_cumulative(
          entries :: [tuple()],
          boundaries :: [number()],
          num_buckets :: pos_integer(),
          now :: integer()
        ) :: [Otel.SDK.Metrics.Aggregation.datapoint()]
  defp collect_cumulative(entries, boundaries, num_buckets, now) do
    Enum.map(entries, fn {attributes, counters_ref, min, max, sum, count, start_time} ->
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

  @spec collect_delta(
          metrics_tab :: :ets.table(),
          entries :: [tuple()],
          stream_name :: String.t(),
          scope :: Otel.API.InstrumentationScope.t(),
          reader_id :: reference() | nil,
          boundaries :: [number()],
          num_buckets :: pos_integer(),
          now :: integer()
        ) :: [Otel.SDK.Metrics.Aggregation.datapoint()]
  defp collect_delta(
         metrics_tab,
         entries,
         stream_name,
         scope,
         reader_id,
         boundaries,
         num_buckets,
         now
       ) do
    entries
    |> Enum.map(fn {attributes, counters_ref, min, max, sum, count, start_time} ->
      bucket_counts = read_bucket_counts(counters_ref, num_buckets)
      key = {stream_name, scope, reader_id, attributes}
      reset_histogram(metrics_tab, key, counters_ref, bucket_counts, count, sum, now)

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
    |> Enum.reject(fn dp -> dp.value.count == 0 end)
  end

  @spec reset_histogram(
          metrics_tab :: :ets.table(),
          key :: term(),
          counters_ref :: :counters.counters_ref(),
          bucket_counts :: [non_neg_integer()],
          count :: non_neg_integer(),
          sum :: number(),
          now :: integer()
        ) :: :ok
  defp reset_histogram(metrics_tab, key, counters_ref, bucket_counts, count, sum, now) do
    Enum.each(Enum.with_index(bucket_counts, 1), fn {cnt, idx} ->
      :counters.sub(counters_ref, idx, cnt)
    end)

    :ets.update_counter(metrics_tab, key, [{@count_pos, -count}])
    reset_sum_field(metrics_tab, key, sum)
    :ets.update_element(metrics_tab, key, [{3, :unset}, {4, :unset}])
    :ets.update_element(metrics_tab, key, [{7, now}])
    :ok
  end

  @spec reset_sum_field(metrics_tab :: :ets.table(), key :: term(), sum :: number()) :: :ok
  defp reset_sum_field(metrics_tab, key, sum) when is_integer(sum) do
    :ets.update_counter(metrics_tab, key, [{@sum_pos, -sum}])
    :ok
  end

  defp reset_sum_field(metrics_tab, key, sum) when is_float(sum) do
    [{^key, _, _, _, old_sum, _, _}] = :ets.lookup(metrics_tab, key)
    :ets.update_element(metrics_tab, key, [{@sum_pos, old_sum - sum}])
    :ok
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
        update_count(metrics_tab, key)
        update_sum_init(metrics_tab, key, value)
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

  @spec update_count(metrics_tab :: :ets.table(), key :: term()) :: :ok
  defp update_count(metrics_tab, key) do
    :ets.update_counter(metrics_tab, key, [{@count_pos, 1}])
    :ok
  end

  @spec update_sum_init(metrics_tab :: :ets.table(), key :: term(), value :: number()) :: :ok
  defp update_sum_init(metrics_tab, key, value) do
    :ets.update_element(metrics_tab, key, [{@sum_pos, value}])
    :ok
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
