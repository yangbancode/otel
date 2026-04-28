defmodule Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogramTest do
  use ExUnit.Case, async: true

  @scope %Otel.API.InstrumentationScope{name: "test"}
  @boundaries [10, 50, 100]

  setup do
    %{tab: :ets.new(:hist_test, [:set, :public]), opts: %{boundaries: @boundaries}}
  end

  defp key(attrs \\ %{}), do: {"histogram", @scope, nil, attrs}

  defp datapoint(tab, opts) do
    [dp] =
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
        tab,
        {"histogram", @scope},
        opts
      )

    dp
  end

  test "default_boundaries/0 returns the OTel-spec defaults" do
    assert Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.default_boundaries() ==
             [0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10_000]
  end

  describe "aggregate/4 + collect/3" do
    # Spec metrics/sdk.md L1314 — bucket boundaries are inclusive
    # upper bounds; a value equal to a boundary lands in the lower bucket.
    test "places each value in the right bucket and tracks count, sum, min, max",
         %{tab: tab, opts: opts} do
      # 5 → bucket 0 (≤10), 10 → bucket 0 (boundary→lower),
      # 75 → bucket 2 (≤100), 200 → bucket 3 (overflow).
      for v <- [5, 10, 75, 200] do
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), v, opts)
      end

      dp = datapoint(tab, opts)

      assert dp.value.bucket_counts == [2, 0, 1, 1]
      assert dp.value.boundaries == @boundaries
      assert dp.value.count == 4
      assert dp.value.sum == 290
      assert dp.value.min == 5
      assert dp.value.max == 200
    end

    test "tracks float sum precisely", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 1.5, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 2.5, opts)

      assert_in_delta datapoint(tab, opts).value.sum, 4.0, 0.001
    end

    test "keeps separate datapoints per attribute set", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(
        tab,
        key(%{"m" => "GET"}),
        5,
        opts
      )

      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(
        tab,
        key(%{"m" => "POST"}),
        15,
        opts
      )

      dps =
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      assert length(dps) == 2
    end

    test "empty result for an unknown stream key", %{tab: tab, opts: opts} do
      assert [] =
               Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
                 tab,
                 {"other", @scope},
                 opts
               )
    end
  end

  # Spec metrics/sdk.md L662 RecordMinMax option — when false, the
  # collector emits nil min/max but everything else (count, sum,
  # buckets) keeps tracking.
  describe "record_min_max: false" do
    setup do
      %{opts: %{boundaries: @boundaries, record_min_max: false}}
    end

    test "first and subsequent aggregates leave min/max as nil; count/sum/buckets unaffected",
         %{tab: tab, opts: opts} do
      for v <- [5, 80, 12] do
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), v, opts)
      end

      dp = datapoint(tab, opts)
      assert dp.value.min == nil
      assert dp.value.max == nil
      assert dp.value.count == 3
      assert dp.value.sum == 97
      assert Enum.sum(dp.value.bucket_counts) == 3
    end
  end
end
