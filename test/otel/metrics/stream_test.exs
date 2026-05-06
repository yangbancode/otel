defmodule Otel.Metrics.StreamTest do
  use ExUnit.Case, async: true

  defp instrument(overrides \\ %{}) do
    Map.merge(
      %Otel.Metrics.Instrument{
        name: "http.request.duration",
        kind: :histogram,
        unit: "ms",
        description: "Request duration",
        advisory: [],
        scope: Otel.InstrumentationScope.new(%{name: "my_lib"})
      },
      overrides
    )
  end

  describe "from_instrument/1" do
    test "carries instrument identity; resolution-time fields default to nil" do
      inst = instrument()
      stream = Otel.Metrics.Stream.from_instrument(inst)

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
      assert Otel.Metrics.Stream.from_instrument(instrument(%{kind: :counter}))
             |> Otel.Metrics.Stream.resolve()
             |> Map.fetch!(:aggregation) == Otel.Metrics.Aggregation.Sum

      assert Otel.Metrics.Stream.from_instrument(instrument(%{kind: :gauge}))
             |> Otel.Metrics.Stream.resolve()
             |> Map.fetch!(:aggregation) == Otel.Metrics.Aggregation.LastValue

      assert Otel.Metrics.Stream.from_instrument(instrument())
             |> Otel.Metrics.Stream.resolve()
             |> Map.fetch!(:aggregation) == Otel.Metrics.Aggregation.ExplicitBucketHistogram
    end

    test "advisory boundaries flow into aggregation_options" do
      inst = instrument(%{advisory: [explicit_bucket_boundaries: [1, 5, 10]]})

      assert Otel.Metrics.Stream.from_instrument(inst)
             |> Otel.Metrics.Stream.resolve()
             |> get_in([Access.key!(:aggregation_options), :boundaries]) == [1, 5, 10]
    end

    test "fills cardinality limit and reservoir defaults" do
      stream =
        instrument()
        |> Otel.Metrics.Stream.from_instrument()
        |> Otel.Metrics.Stream.resolve()

      assert stream.aggregation_cardinality_limit == 2000

      assert stream.exemplar_reservoir ==
               Otel.Metrics.Exemplar.Reservoir.AlignedHistogramBucket

      counter_stream =
        instrument(%{kind: :counter})
        |> Otel.Metrics.Stream.from_instrument()
        |> Otel.Metrics.Stream.resolve()

      assert counter_stream.exemplar_reservoir ==
               Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize
    end
  end
end
