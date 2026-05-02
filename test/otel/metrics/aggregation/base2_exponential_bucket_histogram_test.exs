defmodule Otel.Metrics.Aggregation.Base2ExponentialBucketHistogramTest do
  use ExUnit.Case, async: true

  @scope %Otel.InstrumentationScope{name: "test"}

  setup do
    %{tab: :ets.new(:b2e_test, [:set, :public]), opts: %{}}
  end

  defp key(attrs \\ %{}), do: {"histogram", @scope, nil, attrs}

  defp datapoint(tab, opts) do
    [dp] =
      Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.collect(
        tab,
        {"histogram", @scope},
        opts
      )

    dp
  end

  describe "map_to_index/2" do
    # Spec data-model.md L860-L869 — for IEEE-exact powers of two,
    # the index is `((ieee_exp) << scale) - 1`.
    test "exact powers of two follow the closed-form formula across scales" do
      # value=1 → ieee_exp=0; value=2 → 1; value=4 → 2; value=8 → 3.
      assert Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.map_to_index(1.0, 0) ==
               -1

      assert Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.map_to_index(2.0, 0) ==
               0

      assert Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.map_to_index(4.0, 0) ==
               1

      assert Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.map_to_index(8.0, 0) ==
               2

      # Scale 1: indices double-step.
      assert Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.map_to_index(2.0, 1) ==
               1

      assert Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.map_to_index(4.0, 1) ==
               3
    end

    test "non-power-of-two values fall via the log path" do
      # 1 < 1.5 < 2 → bucket 0 at scale 0.
      assert Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.map_to_index(1.5, 0) ==
               0

      assert Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.map_to_index(3.0, 0) ==
               1

      # Scale 3 example from spec L626 — 1.09051 ≈ 2**(1/8) hits bucket 1.
      assert Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.map_to_index(1.09051, 3) ==
               1
    end

    test "values < 1 produce negative indices" do
      assert Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.map_to_index(0.5, 0) ==
               -2

      assert Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.map_to_index(0.25, 0) ==
               -3
    end
  end

  describe "aggregate/4 — value placement by sign" do
    test "zeros increment zero_count; non-zero values populate positive/negative buckets",
         %{tab: tab, opts: opts} do
      for v <- [0, 0.0, 5, -4.0, -8.0] do
        Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
          tab,
          key(),
          v,
          opts
        )
      end

      dp = datapoint(tab, opts)
      assert dp.value.zero_count == 2
      assert dp.value.count == 5
      assert Enum.sum(dp.value.positive.bucket_counts) == 1
      assert Enum.sum(dp.value.negative.bucket_counts) == 2
    end

    test "tracks min/max across positive and negative ranges", %{tab: tab, opts: opts} do
      for v <- [1.5, 100.0, 10.0, -1.0, -100.0] do
        Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
          tab,
          key(),
          v,
          opts
        )
      end

      dp = datapoint(tab, opts)
      assert dp.value.min == -100.0
      assert dp.value.max == 100.0
    end

    test "values in the same bucket increment the same counter", %{tab: tab, opts: opts} do
      Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
        tab,
        key(),
        3.0,
        opts
      )

      Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
        tab,
        key(),
        3.5,
        opts
      )

      dp = datapoint(tab, opts)
      assert dp.value.count == 2
      assert Enum.sum(dp.value.positive.bucket_counts) == 2
    end
  end

  test "record_min_max: false leaves min/max nil", %{tab: tab} do
    opts = %{record_min_max: false}

    Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(tab, key(), 1.0, opts)

    Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
      tab,
      key(),
      100.0,
      opts
    )

    dp = datapoint(tab, opts)
    assert dp.value.min == nil
    assert dp.value.max == nil
    assert dp.value.count == 2
  end

  describe "auto-rescale" do
    # Spec L740-L744 SHOULD: a single value keeps the maximum scale;
    # a span that exceeds max_size triggers downscale.
    test "single measurement keeps max_scale; many measurements force downscale", %{tab: tab} do
      single_opts = %{max_size: 160, max_scale: 20}

      Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
        tab,
        key(),
        1.5,
        single_opts
      )

      assert datapoint(tab, single_opts).value.scale == 20

      tab2 = :ets.new(:b2e_rescale, [:set, :public])
      crowded_opts = %{max_size: 4, max_scale: 20}

      for v <- 1..16 do
        Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
          tab2,
          key(),
          v * 1.0,
          crowded_opts
        )
      end

      [dp] =
        Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.collect(
          tab2,
          {"histogram", @scope},
          crowded_opts
        )

      assert dp.value.count == 16
      assert length(dp.value.positive.bucket_counts) <= 4
      assert dp.value.scale < 20
    end
  end

  describe "collect/3 temporality" do
    test "cumulative — preserves state across collect calls; empty stream → []",
         %{tab: tab, opts: opts} do
      assert [] =
               Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.collect(
                 tab,
                 {"histogram", @scope},
                 opts
               )

      Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
        tab,
        key(),
        5.0,
        opts
      )

      [dp1] =
        Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      [dp2] =
        Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      assert dp1.value.count == 1
      assert dp2.value.count == 1
      assert dp1.start_time == dp2.start_time
    end

    test "delta — resets count, sum, min, max after each collect", %{tab: tab} do
      opts = %{temporality: :delta}

      Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
        tab,
        key(),
        1.0,
        opts
      )

      Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
        tab,
        key(),
        2.0,
        opts
      )

      dp1 = datapoint(tab, opts)
      assert dp1.value.count == 2
      assert dp1.value.sum == 3.0

      # No new measurements → empty (delta filters empty datapoints).
      assert [] =
               Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.collect(
                 tab,
                 {"histogram", @scope},
                 opts
               )

      Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
        tab,
        key(),
        100.0,
        opts
      )

      dp2 = datapoint(tab, opts)
      assert dp2.value.count == 1
      assert dp2.value.sum == 100.0
      assert dp2.value.max == 100.0
    end
  end

  test "datapoint exposes proto-shaped fields", %{tab: tab, opts: opts} do
    Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(tab, key(), 4.0, opts)

    dp = datapoint(tab, opts)

    assert is_integer(dp.value.scale)
    assert is_integer(dp.value.zero_count)
    assert dp.value.zero_threshold == 0.0
    assert Map.has_key?(dp.value.positive, :offset)
    assert Map.has_key?(dp.value.positive, :bucket_counts)
    assert Map.has_key?(dp.value.negative, :offset)
    assert Map.has_key?(dp.value.negative, :bucket_counts)
  end

  test "tracks separate state per attribute set", %{tab: tab, opts: opts} do
    Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
      tab,
      key(%{"k" => "a"}),
      1.0,
      opts
    )

    Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
      tab,
      key(%{"k" => "a"}),
      2.0,
      opts
    )

    Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.aggregate(
      tab,
      key(%{"k" => "b"}),
      100.0,
      opts
    )

    dps =
      Otel.Metrics.Aggregation.Base2ExponentialBucketHistogram.collect(
        tab,
        {"histogram", @scope},
        opts
      )

    assert length(dps) == 2
    by_attrs = Map.new(dps, &{&1.attributes, &1.value})
    assert by_attrs[%{"k" => "a"}].count == 2
    assert by_attrs[%{"k" => "b"}].count == 1
  end
end
