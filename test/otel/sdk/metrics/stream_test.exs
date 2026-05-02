defmodule Otel.SDK.Metrics.StreamTest do
  use ExUnit.Case, async: true

  defp instrument(overrides \\ %{}) do
    Map.merge(
      %Otel.API.Metrics.Instrument{
        name: "http.request.duration",
        kind: :histogram,
        unit: "ms",
        description: "Request duration",
        advisory: [],
        scope: %Otel.InstrumentationScope{name: "my_lib"}
      },
      overrides
    )
  end

  describe "from_instrument/1" do
    test "carries instrument identity; resolution-time fields default to nil" do
      inst = instrument()
      stream = Otel.SDK.Metrics.Stream.from_instrument(inst)

      assert stream.name == inst.name
      assert stream.description == inst.description
      assert stream.instrument == inst
      assert stream.aggregation == nil
      assert stream.exemplar_reservoir == nil
      assert stream.aggregation_cardinality_limit == nil
    end
  end

  describe "resolve/1 — fills aggregation default and merges advisory boundaries" do
    test "aggregation resolves to the kind's default" do
      assert Otel.SDK.Metrics.Stream.from_instrument(instrument(%{kind: :counter}))
             |> Otel.SDK.Metrics.Stream.resolve()
             |> Map.fetch!(:aggregation) == Otel.SDK.Metrics.Aggregation.Sum

      assert Otel.SDK.Metrics.Stream.from_instrument(instrument(%{kind: :gauge}))
             |> Otel.SDK.Metrics.Stream.resolve()
             |> Map.fetch!(:aggregation) == Otel.SDK.Metrics.Aggregation.LastValue

      assert Otel.SDK.Metrics.Stream.from_instrument(instrument())
             |> Otel.SDK.Metrics.Stream.resolve()
             |> Map.fetch!(:aggregation) == Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram
    end

    test "advisory boundaries flow into aggregation_options" do
      inst = instrument(%{advisory: [explicit_bucket_boundaries: [1, 5, 10]]})

      assert Otel.SDK.Metrics.Stream.from_instrument(inst)
             |> Otel.SDK.Metrics.Stream.resolve()
             |> get_in([Access.key!(:aggregation_options), :boundaries]) == [1, 5, 10]
    end

    test "fills cardinality limit and reservoir defaults" do
      stream =
        instrument()
        |> Otel.SDK.Metrics.Stream.from_instrument()
        |> Otel.SDK.Metrics.Stream.resolve()

      assert stream.aggregation_cardinality_limit == 2000

      assert stream.exemplar_reservoir ==
               Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket

      counter_stream =
        instrument(%{kind: :counter})
        |> Otel.SDK.Metrics.Stream.from_instrument()
        |> Otel.SDK.Metrics.Stream.resolve()

      assert counter_stream.exemplar_reservoir ==
               Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize
    end
  end
end
