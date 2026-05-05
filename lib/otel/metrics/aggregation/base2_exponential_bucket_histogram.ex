defmodule Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram do
  @moduledoc """
  Base2 Exponential Bucket Histogram aggregation
  (`metrics/sdk.md` §Base2 Exponential Bucket Histogram
  Aggregation L670-L760, Status: **Stable**, v1.55.0).

  Compresses bucket boundaries using `base = 2^(2^-scale)`,
  yielding a high-dynamic-range histogram with bounded
  relative error per bucket. Bucket index `i` holds
  measurements in `(base^i, base^(i+1)]`.

  ## Configuration parameters

  Pass via `opts` (typically through `Stream.aggregation_options`):

  | Key | Default | Description |
  |---|---|---|
  | `:max_size` | 160 | Max buckets per range (positive/negative) — spec L680 |
  | `:max_scale` | 20 | Max scale parameter — spec L680 |
  | `:record_min_max` | `true` | Whether to record min/max — spec L680 |

  The `:zero_threshold` field is fixed at `0` in this
  implementation; values that map exactly to zero (or
  underflow to subnormal-zero) accumulate into `zero_count`.

  ## Storage and concurrency

  Each `(stream_key, reader_id, attributes)` cell holds a
  single ETS row carrying the full per-cell state in a map.
  `aggregate/4` is read-modify-write under the same key.
  Concurrent `aggregate/4` calls on the same attribute cell
  may lose updates; the design assumes write-serialised
  use through `Otel.Metrics.MetricExporter.collect/1` and
  the single-writer instrument facade. This trade-off
  matches Java OTel SDK's synchronized-block approach
  ported to ETS.

  ## Mapping function

  Uses the logarithm method documented in spec
  `metrics/data-model.md` §"All Scales: Use the Logarithm
  Function" L820-L880, with a special case for exact
  powers of two (spec L867-L869). The natural-logarithm
  formula is exact except near power-of-two boundaries,
  where `:math.log/1` accumulated error can produce off-by-
  one results — the special case eliminates this.

  ## Auto-scale-down

  When a measurement would push the populated-bucket count
  beyond `:max_size`, the histogram downscales by 1
  (`scale - 1`) and merges adjacent buckets. Spec
  `metrics/sdk.md` §"Maintain the ideal scale" L755-L760
  SHOULD: *"adjust the histogram scale as necessary to
  maintain the best resolution possible, within the
  constraint of maximum size."* Downscale repeats until the
  measurement fits.

  ## References

  - SDK §Base2 Exponential Bucket Histogram Aggregation:
    `opentelemetry-specification/specification/metrics/sdk.md`
    L670-L760
  - Data model §ExponentialHistogram:
    `opentelemetry-specification/specification/metrics/data-model.md`
    L539-L955
  - Proto `ExponentialHistogramDataPoint`:
    `opentelemetry-proto/opentelemetry/proto/metrics/v1/metrics.proto`
    L222
  """

  @default_max_size 160
  @default_max_scale 20

  @typedoc """
  Per-cell state stored in ETS as the second tuple element:
  `{key, state}`.
  """
  @type state :: %{
          scale: integer(),
          positive: %{integer() => non_neg_integer()},
          negative: %{integer() => non_neg_integer()},
          zero_count: non_neg_integer(),
          min: number() | :unset,
          max: number() | :unset,
          sum: number(),
          count: non_neg_integer(),
          start_time: non_neg_integer()
        }

  @spec aggregate(
          metrics_tab :: :ets.table(),
          key :: term(),
          value :: number(),
          opts :: map()
        ) :: :ok
  def aggregate(metrics_tab, key, value, opts) do
    max_size = Map.get(opts, :max_size, @default_max_size)
    max_scale = Map.get(opts, :max_scale, @default_max_scale)
    record_min_max = Map.get(opts, :record_min_max, true)

    if normal?(value) do
      do_aggregate(metrics_tab, key, value, max_size, max_scale, record_min_max)
    end

    :ok
  end

  @spec collect(
          metrics_tab :: :ets.table(),
          stream_key :: {String.t(), Otel.InstrumentationScope.t()},
          opts :: map()
        ) :: [Otel.Metrics.Aggregation.datapoint()]
  def collect(metrics_tab, {stream_name, scope}, opts) do
    reader_id = Map.get(opts, :reader_id)
    temporality = Map.get(opts, :temporality, :cumulative)
    now = System.system_time(:nanosecond)

    match_spec = [
      {
        {{stream_name, scope, reader_id, :"$1"}, :"$2"},
        [],
        [{{:"$1", :"$2"}}]
      }
    ]

    entries = :ets.select(metrics_tab, match_spec)

    case temporality do
      :cumulative -> collect_cumulative(entries, now)
      :delta -> collect_delta(metrics_tab, entries, stream_name, scope, reader_id, now)
    end
  end

  @spec collect_cumulative(
          entries :: [{map(), state()}],
          now :: non_neg_integer()
        ) :: [Otel.Metrics.Aggregation.datapoint()]
  defp collect_cumulative(entries, now) do
    Enum.map(entries, fn {attributes, state} ->
      %{
        attributes: attributes,
        value: build_value(state),
        start_time: state.start_time,
        time: now
      }
    end)
  end

  @spec collect_delta(
          metrics_tab :: :ets.table(),
          entries :: [{map(), state()}],
          stream_name :: String.t(),
          scope :: Otel.InstrumentationScope.t(),
          reader_id :: reference() | nil,
          now :: non_neg_integer()
        ) :: [Otel.Metrics.Aggregation.datapoint()]
  defp collect_delta(metrics_tab, entries, stream_name, scope, reader_id, now) do
    entries
    |> Enum.map(fn {attributes, state} ->
      key = {stream_name, scope, reader_id, attributes}
      reset_to_empty(metrics_tab, key, state, now)

      %{
        attributes: attributes,
        value: build_value(state),
        start_time: state.start_time,
        time: now
      }
    end)
    |> Enum.reject(fn dp -> dp.value.count == 0 end)
  end

  @spec build_value(state :: state()) :: map()
  defp build_value(state) do
    %{
      scale: state.scale,
      positive: dense_buckets(state.positive),
      negative: dense_buckets(state.negative),
      zero_count: state.zero_count,
      zero_threshold: 0.0,
      min: normalize(state.min),
      max: normalize(state.max),
      sum: state.sum,
      count: state.count
    }
  end

  # Convert a sparse `%{index => count}` map into the dense
  # `%{offset, [counts...]}` proto representation. Empty input
  # produces `%{offset: 0, bucket_counts: []}`.
  @spec dense_buckets(buckets :: %{integer() => non_neg_integer()}) :: %{
          offset: integer(),
          bucket_counts: [non_neg_integer()]
        }
  defp dense_buckets(buckets) when map_size(buckets) == 0 do
    %{offset: 0, bucket_counts: []}
  end

  defp dense_buckets(buckets) do
    indexes = Map.keys(buckets)
    offset = Enum.min(indexes)
    max_idx = Enum.max(indexes)

    counts =
      Enum.map(offset..max_idx, fn i -> Map.get(buckets, i, 0) end)

    %{offset: offset, bucket_counts: counts}
  end

  @spec normalize(value :: number() | :unset) :: number() | nil
  defp normalize(:unset), do: nil
  defp normalize(value), do: value

  # Spec L735-L737: SHOULD NOT incorporate +Inf, -Inf, NaN
  # into sum/min/max — they don't map into a valid bucket.
  # Erlang/Elixir do not represent these as ordinary float
  # values (operations that would produce them raise), so by
  # the time `aggregate/4` runs the input is already a finite
  # number. The guard keeps the module's contract explicit.
  @spec normal?(value :: number()) :: boolean()
  defp normal?(value), do: is_number(value)

  @spec do_aggregate(
          metrics_tab :: :ets.table(),
          key :: term(),
          value :: number(),
          max_size :: pos_integer(),
          max_scale :: integer(),
          record_min_max :: boolean()
        ) :: :ok
  defp do_aggregate(metrics_tab, key, value, max_size, max_scale, record_min_max) do
    case :ets.lookup(metrics_tab, key) do
      [{^key, state}] ->
        new_state = record_value(state, value, max_size, record_min_max)
        :ets.insert(metrics_tab, {key, new_state})
        :ok

      [] ->
        new_state = record_value(initial_state(max_scale), value, max_size, record_min_max)

        case :ets.insert_new(metrics_tab, {key, new_state}) do
          true -> :ok
          false -> do_aggregate(metrics_tab, key, value, max_size, max_scale, record_min_max)
        end
    end
  end

  @spec initial_state(max_scale :: integer()) :: state()
  defp initial_state(max_scale) do
    %{
      scale: max_scale,
      positive: %{},
      negative: %{},
      zero_count: 0,
      min: :unset,
      max: :unset,
      sum: 0,
      count: 0,
      start_time: System.system_time(:nanosecond)
    }
  end

  # Record a single normal value into the aggregation state.
  # Routes the value to zero / positive / negative bucket per
  # data-model L605-L612, applying scale downshift when the
  # selected range would exceed `max_size` populated buckets.
  @spec record_value(
          state :: state(),
          value :: number(),
          max_size :: pos_integer(),
          record_min_max :: boolean()
        ) :: state()
  defp record_value(state, value, max_size, record_min_max) do
    state =
      cond do
        value == 0 or value == 0.0 ->
          %{state | zero_count: state.zero_count + 1}

        value > 0 ->
          state
          |> place_in_range(:positive, value)
          |> maybe_downscale(max_size)

        value < 0 ->
          state
          |> place_in_range(:negative, -value)
          |> maybe_downscale(max_size)
      end

    state
    |> Map.update!(:sum, &(&1 + value))
    |> Map.update!(:count, &(&1 + 1))
    |> update_min_max(value, record_min_max)
  end

  # Place an absolute `abs_value` into the given range
  # (`:positive` or `:negative`) at the current scale, without
  # rescaling. Rescaling decisions are deferred to
  # `maybe_downscale/2` after placement so both ranges stay
  # aligned (a downscale touches positive AND negative).
  @spec place_in_range(state :: state(), range :: :positive | :negative, abs_value :: number()) ::
          state()
  defp place_in_range(state, range, abs_value) do
    idx = map_to_index(abs_value, state.scale)
    Map.update!(state, range, fn buckets -> Map.update(buckets, idx, 1, &(&1 + 1)) end)
  end

  # If either range exceeds `max_size` populated-bucket span,
  # downscale the whole state by 1 (both ranges shift in lock-
  # step). Recurse until both ranges fit. Spec L755-L760
  # SHOULD: maintain best resolution within size constraint.
  @spec maybe_downscale(state :: state(), max_size :: pos_integer()) :: state()
  defp maybe_downscale(state, max_size) do
    if populated_within_size?(state.positive, max_size) and
         populated_within_size?(state.negative, max_size) do
      state
    else
      state |> downscale_state() |> maybe_downscale(max_size)
    end
  end

  @spec populated_within_size?(
          range :: %{integer() => non_neg_integer()},
          max_size :: pos_integer()
        ) :: boolean()
  defp populated_within_size?(range, _max_size) when map_size(range) == 0, do: true

  defp populated_within_size?(range, max_size) do
    indexes = Map.keys(range)
    span = Enum.max(indexes) - Enum.min(indexes) + 1
    span <= max_size
  end

  # Downscale the entire state by 1: each bucket index `i`
  # collapses to `i >>> 1`, counts merge by addition, and
  # `state.scale` decrements by 1. Spec data-model L598-L599
  # *"perfect subsetting"* — buckets at scale `s` map exactly
  # into scale `s-1` with no error.
  @spec downscale_state(state :: state()) :: state()
  defp downscale_state(state) do
    %{
      state
      | scale: state.scale - 1,
        positive: collapse_buckets(state.positive),
        negative: collapse_buckets(state.negative)
    }
  end

  @spec collapse_buckets(buckets :: %{integer() => non_neg_integer()}) ::
          %{integer() => non_neg_integer()}
  defp collapse_buckets(buckets) do
    Enum.reduce(buckets, %{}, fn {idx, count}, acc ->
      Map.update(acc, Bitwise.bsr(idx, 1), count, &(&1 + count))
    end)
  end

  # Spec data-model.md §"All Scales: Use the Logarithm
  # Function" L820-L869: index = floor(log_2(value) * 2^scale)
  # for non-power-of-two values, with the explicit
  # ((exp - 1) <<< scale) - 1 special case for exact powers
  # of two (spec L860-L869).
  @spec map_to_index(value :: number(), scale :: integer()) :: integer()
  def map_to_index(value, scale) when is_number(value) and value > 0 do
    fvalue = value * 1.0
    <<_sign::1, raw_exp::11, frac::52>> = <<fvalue::float-64>>

    # IEEE 754 power-of-two: significand bits are all zero and
    # rawExponent is in the normal range [1, 2046]. (raw_exp = 0
    # is subnormal; raw_exp = 2047 is Inf/NaN — Erlang doesn't
    # surface these as floats, but the guard is defensive.)
    if frac == 0 and raw_exp != 0 and raw_exp != 2047 do
      # Spec L860-L869: ((exp - 1) << scale) - 1 where `exp`
      # is from frexp, which equals ieee_exp + 1. So:
      # ((ieee_exp + 1) - 1) << scale - 1 = (ieee_exp << scale) - 1
      ieee_exp = raw_exp - 1023
      Bitwise.bsl(ieee_exp, scale) - 1
    else
      log2 = :math.log2(fvalue)
      floor(log2 * :math.pow(2, scale))
    end
  end

  @spec update_min_max(state :: state(), value :: number(), record_min_max :: boolean()) ::
          state()
  defp update_min_max(state, _value, false), do: state

  defp update_min_max(state, value, true) do
    new_min =
      cond do
        state.min == :unset -> value
        value < state.min -> value
        true -> state.min
      end

    new_max =
      cond do
        state.max == :unset -> value
        value > state.max -> value
        true -> state.max
      end

    %{state | min: new_min, max: new_max}
  end

  @spec reset_to_empty(
          metrics_tab :: :ets.table(),
          key :: term(),
          old_state :: state(),
          now :: non_neg_integer()
        ) :: :ok
  defp reset_to_empty(metrics_tab, key, old_state, now) do
    fresh = %{
      scale: old_state.scale,
      positive: %{},
      negative: %{},
      zero_count: 0,
      min: :unset,
      max: :unset,
      sum: 0,
      count: 0,
      start_time: now
    }

    :ets.insert(metrics_tab, {key, fresh})
    :ok
  end
end
