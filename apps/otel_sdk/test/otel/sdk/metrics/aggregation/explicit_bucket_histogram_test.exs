defmodule Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogramTest do
  use ExUnit.Case, async: true

  @scope %Otel.API.InstrumentationScope{name: "test"}
  @boundaries [10, 50, 100]

  setup do
    tab = :ets.new(:test_metrics, [:set, :public])
    %{tab: tab, opts: %{boundaries: @boundaries}}
  end

  defp key(attrs \\ %{}), do: {"histogram", @scope, attrs}

  describe "aggregate/4" do
    test "creates entry on first aggregate", %{tab: tab, opts: opts} do
      assert :ok ==
               Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(
                 tab,
                 key(),
                 5,
                 opts
               )

      assert length(:ets.tab2list(tab)) == 1
    end

    test "increments correct bucket", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 5, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 15, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 75, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 200, opts)

      [dp] =
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      assert dp.value.bucket_counts == [1, 1, 1, 1]
    end

    test "tracks count", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 1, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 2, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 3, opts)

      [dp] =
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      assert dp.value.count == 3
    end

    test "tracks integer sum", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 10, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 20, opts)

      [dp] =
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      assert dp.value.sum == 30
    end

    test "tracks float sum", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 1.5, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 2.5, opts)

      [dp] =
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      assert_in_delta dp.value.sum, 4.0, 0.001
    end

    test "tracks min", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 50, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 10, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 30, opts)

      [dp] =
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      assert dp.value.min == 10
    end

    test "tracks max", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 10, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 90, opts)
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 50, opts)

      [dp] =
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      assert dp.value.max == 90
    end

    test "boundary value goes in lower bucket", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 10, opts)

      [dp] =
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      assert dp.value.bucket_counts == [1, 0, 0, 0]
    end

    test "value above all boundaries goes in last bucket", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 999, opts)

      [dp] =
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      assert dp.value.bucket_counts == [0, 0, 0, 1]
    end

    test "separate entries for different attributes", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(
        tab,
        key(%{m: "GET"}),
        5,
        opts
      )

      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(
        tab,
        key(%{m: "POST"}),
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
  end

  describe "collect/3" do
    test "returns boundaries in datapoint", %{tab: tab, opts: opts} do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.aggregate(tab, key(), 5, opts)

      [dp] =
        Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
          tab,
          {"histogram", @scope},
          opts
        )

      assert dp.value.boundaries == @boundaries
    end

    test "returns empty for non-existent stream", %{tab: tab, opts: opts} do
      assert [] ==
               Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.collect(
                 tab,
                 {"other", @scope},
                 opts
               )
    end
  end

  describe "default_boundaries/0" do
    test "returns spec-defined defaults" do
      assert Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.default_boundaries() ==
               [0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10_000]
    end
  end
end
