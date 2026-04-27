defmodule Otel.SDK.Metrics.Aggregation.Base2ExponentialBucketHistogramTest do
  use ExUnit.Case, async: true

  alias Otel.SDK.Metrics.Aggregation.Base2ExponentialBucketHistogram, as: B2E

  @scope %Otel.API.InstrumentationScope{name: "test"}

  setup do
    tab = :ets.new(:test_metrics, [:set, :public])
    %{tab: tab, opts: %{}}
  end

  defp key(attrs \\ %{}), do: {"histogram", @scope, nil, attrs}

  describe "map_to_index/2" do
    test "exact powers of two at scale 0" do
      # Spec data-model.md L860-L869 power-of-two special case:
      # ((exp - 1) << scale) - 1, equivalent to (ieee_exp << scale) - 1.
      # value=1 -> ieee_exp=0 -> (0 << 0) - 1 = -1
      assert B2E.map_to_index(1.0, 0) == -1
      # value=2 -> ieee_exp=1 -> (1 << 0) - 1 = 0
      assert B2E.map_to_index(2.0, 0) == 0
      # value=4 -> ieee_exp=2 -> (2 << 0) - 1 = 1
      assert B2E.map_to_index(4.0, 0) == 1
      # value=8 -> ieee_exp=3 -> (3 << 0) - 1 = 2
      assert B2E.map_to_index(8.0, 0) == 2
    end

    test "exact powers of two at scale 1" do
      # value=1 -> (0 << 1) - 1 = -1
      assert B2E.map_to_index(1.0, 1) == -1
      # value=2 -> (1 << 1) - 1 = 1
      assert B2E.map_to_index(2.0, 1) == 1
      # value=4 -> (2 << 1) - 1 = 3
      assert B2E.map_to_index(4.0, 1) == 3
    end

    test "non-power-of-two at scale 0 falls between integer powers" do
      # 1 < 1.5 < 2 -> bucket 0 (since 2^0 < 1.5 <= 2^1)
      # floor(log2(1.5) * 1) = floor(0.585) = 0
      assert B2E.map_to_index(1.5, 0) == 0
      # 2 < 3 < 4 -> bucket 1
      assert B2E.map_to_index(3.0, 0) == 1
    end

    test "non-power-of-two at scale 3 (8 buckets per power of 2)" do
      # Spec data-model.md L626 example: 8 buckets between 1 and 2
      # 1.09051 falls in bucket 1 (boundary 2**(1/8))
      assert B2E.map_to_index(1.09051, 3) == 1
      # 1.18921 (= 2**(2/8) = 2**(1/4)) — power of 2^(1/4) but
      # not power of 2 in IEEE; falls into bucket 2 via log path
      assert B2E.map_to_index(1.18921, 3) == 2
    end

    test "very small positive values" do
      assert B2E.map_to_index(0.5, 0) == -2
      assert B2E.map_to_index(0.25, 0) == -3
    end
  end

  describe "aggregate/4 zero" do
    test "zero counts go to zero_count, not buckets", %{tab: tab, opts: opts} do
      :ok = B2E.aggregate(tab, key(), 0, opts)
      :ok = B2E.aggregate(tab, key(), 0.0, opts)
      :ok = B2E.aggregate(tab, key(), 5, opts)

      [dp] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp.value.zero_count == 2
      assert dp.value.count == 3
      assert dp.value.positive.bucket_counts |> Enum.sum() == 1
    end
  end

  describe "aggregate/4 positive" do
    test "single positive value populates positive range", %{tab: tab, opts: opts} do
      :ok = B2E.aggregate(tab, key(), 4.0, opts)

      [dp] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp.value.count == 1
      assert dp.value.sum == 4.0
      assert dp.value.zero_count == 0
      assert dp.value.negative.bucket_counts == []
      assert Enum.sum(dp.value.positive.bucket_counts) == 1
    end

    test "two values in same bucket increment count", %{tab: tab, opts: opts} do
      :ok = B2E.aggregate(tab, key(), 3.0, opts)
      :ok = B2E.aggregate(tab, key(), 3.5, opts)

      [dp] = B2E.collect(tab, {"histogram", @scope}, opts)
      # Both 3.0 and 3.5 fall into the same bucket at scale 20
      # (within (2, 4]); bucket count is 2
      assert dp.value.count == 2
      assert Enum.sum(dp.value.positive.bucket_counts) == 2
    end

    test "tracks min/max for positive values", %{tab: tab, opts: opts} do
      :ok = B2E.aggregate(tab, key(), 1.5, opts)
      :ok = B2E.aggregate(tab, key(), 100.0, opts)
      :ok = B2E.aggregate(tab, key(), 10.0, opts)

      [dp] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp.value.min == 1.5
      assert dp.value.max == 100.0
    end
  end

  describe "aggregate/4 negative" do
    test "negative values go to negative range", %{tab: tab, opts: opts} do
      :ok = B2E.aggregate(tab, key(), -4.0, opts)
      :ok = B2E.aggregate(tab, key(), -8.0, opts)

      [dp] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp.value.count == 2
      assert dp.value.sum == -12.0
      assert dp.value.positive.bucket_counts == []
      assert Enum.sum(dp.value.negative.bucket_counts) == 2
    end

    test "min reflects most-negative value", %{tab: tab, opts: opts} do
      :ok = B2E.aggregate(tab, key(), -1.0, opts)
      :ok = B2E.aggregate(tab, key(), -100.0, opts)

      [dp] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp.value.min == -100.0
      assert dp.value.max == -1.0
    end
  end

  describe "aggregate/4 record_min_max=false" do
    test "min/max stay nil when record_min_max false", %{tab: tab} do
      opts = %{record_min_max: false}
      :ok = B2E.aggregate(tab, key(), 1.0, opts)
      :ok = B2E.aggregate(tab, key(), 100.0, opts)

      [dp] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp.value.min == nil
      assert dp.value.max == nil
      assert dp.value.count == 2
    end
  end

  describe "aggregate/4 auto-rescale" do
    test "downscales when measurements exceed max_size span", %{tab: tab} do
      # max_size=4, max_scale=20. Values 1..16 at scale 20 produce
      # very different bucket indices, forcing repeated downscale
      # until the populated span fits in 4 buckets.
      opts = %{max_size: 4, max_scale: 20}

      Enum.each(1..16, fn v -> :ok = B2E.aggregate(tab, key(), v * 1.0, opts) end)

      [dp] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp.value.count == 16
      assert length(dp.value.positive.bucket_counts) <= 4
      # Scale should have come down from 20 to fit
      assert dp.value.scale < 20
    end

    test "single measurement stays at max_scale", %{tab: tab} do
      # Spec L740-L744 SHOULD: when histogram has not more than
      # one value, use the maximum scale.
      opts = %{max_size: 160, max_scale: 20}

      :ok = B2E.aggregate(tab, key(), 1.5, opts)

      [dp] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp.value.scale == 20
    end
  end

  describe "collect/3 cumulative" do
    test "preserves state across collect calls", %{tab: tab, opts: opts} do
      :ok = B2E.aggregate(tab, key(), 5.0, opts)

      [dp1] = B2E.collect(tab, {"histogram", @scope}, opts)
      [dp2] = B2E.collect(tab, {"histogram", @scope}, opts)

      assert dp1.value.count == 1
      assert dp2.value.count == 1
      assert dp1.start_time == dp2.start_time
    end

    test "returns empty list when no measurements", %{tab: tab, opts: opts} do
      assert [] == B2E.collect(tab, {"histogram", @scope}, opts)
    end
  end

  describe "collect/3 delta" do
    test "resets state after collect", %{tab: tab} do
      opts = %{temporality: :delta}

      :ok = B2E.aggregate(tab, key(), 5.0, opts)
      [dp1] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp1.value.count == 1

      # Second collect with no new measurements: dropped because
      # delta filters empty datapoints
      assert [] == B2E.collect(tab, {"histogram", @scope}, opts)
    end

    test "min/max reset between collects", %{tab: tab} do
      opts = %{temporality: :delta}

      :ok = B2E.aggregate(tab, key(), 100.0, opts)
      [dp1] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp1.value.max == 100.0

      :ok = B2E.aggregate(tab, key(), 5.0, opts)
      [dp2] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp2.value.max == 5.0
    end

    test "sum and count reset between collects", %{tab: tab} do
      opts = %{temporality: :delta}

      :ok = B2E.aggregate(tab, key(), 1.0, opts)
      :ok = B2E.aggregate(tab, key(), 2.0, opts)
      [dp1] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp1.value.count == 2
      assert dp1.value.sum == 3.0

      :ok = B2E.aggregate(tab, key(), 10.0, opts)
      [dp2] = B2E.collect(tab, {"histogram", @scope}, opts)
      assert dp2.value.count == 1
      assert dp2.value.sum == 10.0
    end
  end

  describe "datapoint shape" do
    test "exposes proto-shaped fields", %{tab: tab, opts: opts} do
      :ok = B2E.aggregate(tab, key(), 4.0, opts)

      [dp] = B2E.collect(tab, {"histogram", @scope}, opts)

      assert is_map(dp.value)
      assert is_integer(dp.value.scale)
      assert is_integer(dp.value.zero_count)
      assert dp.value.zero_threshold == 0.0
      assert is_map(dp.value.positive)
      assert is_map(dp.value.negative)
      assert Map.has_key?(dp.value.positive, :offset)
      assert Map.has_key?(dp.value.positive, :bucket_counts)
    end
  end

  describe "multiple attribute sets" do
    test "tracks separate state per attribute set", %{tab: tab, opts: opts} do
      :ok = B2E.aggregate(tab, key(%{"k" => "a"}), 1.0, opts)
      :ok = B2E.aggregate(tab, key(%{"k" => "a"}), 2.0, opts)
      :ok = B2E.aggregate(tab, key(%{"k" => "b"}), 100.0, opts)

      datapoints = B2E.collect(tab, {"histogram", @scope}, opts)
      assert length(datapoints) == 2

      by_attrs = Map.new(datapoints, fn dp -> {dp.attributes, dp.value} end)
      assert by_attrs[%{"k" => "a"}].count == 2
      assert by_attrs[%{"k" => "b"}].count == 1
    end
  end
end
