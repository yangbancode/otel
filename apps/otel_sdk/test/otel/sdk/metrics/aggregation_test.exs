defmodule Otel.SDK.Metrics.AggregationTest do
  use ExUnit.Case, async: true

  describe "default_module/1" do
    test "counter maps to Sum" do
      assert Otel.SDK.Metrics.Aggregation.default_for(:counter) ==
               Otel.SDK.Metrics.Aggregation.Sum
    end

    test "updown_counter maps to Sum" do
      assert Otel.SDK.Metrics.Aggregation.default_for(:updown_counter) ==
               Otel.SDK.Metrics.Aggregation.Sum
    end

    test "histogram maps to ExplicitBucketHistogram" do
      assert Otel.SDK.Metrics.Aggregation.default_for(:histogram) ==
               Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram
    end

    test "gauge maps to LastValue" do
      assert Otel.SDK.Metrics.Aggregation.default_for(:gauge) ==
               Otel.SDK.Metrics.Aggregation.LastValue
    end

    test "observable_counter maps to Sum" do
      assert Otel.SDK.Metrics.Aggregation.default_for(:observable_counter) ==
               Otel.SDK.Metrics.Aggregation.Sum
    end

    test "observable_gauge maps to LastValue" do
      assert Otel.SDK.Metrics.Aggregation.default_for(:observable_gauge) ==
               Otel.SDK.Metrics.Aggregation.LastValue
    end

    test "observable_updown_counter maps to Sum" do
      assert Otel.SDK.Metrics.Aggregation.default_for(:observable_updown_counter) ==
               Otel.SDK.Metrics.Aggregation.Sum
    end
  end
end
