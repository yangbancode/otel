defmodule Otel.Metrics.AggregationTest do
  use ExUnit.Case, async: true

  # Spec metrics/sdk.md L1290-L1297 — default aggregation per
  # instrument kind.
  test "default_for/1 maps every instrument kind to its default aggregation module" do
    expected = %{
      counter: Otel.Metrics.Aggregation.Sum,
      updown_counter: Otel.Metrics.Aggregation.Sum,
      observable_counter: Otel.Metrics.Aggregation.Sum,
      observable_updown_counter: Otel.Metrics.Aggregation.Sum,
      histogram: Otel.Metrics.Aggregation.ExplicitBucketHistogram,
      gauge: Otel.Metrics.Aggregation.LastValue,
      observable_gauge: Otel.Metrics.Aggregation.LastValue
    }

    for {kind, module} <- expected do
      assert Otel.Metrics.Aggregation.default_for(kind) == module
    end
  end
end
