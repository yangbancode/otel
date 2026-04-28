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
        scope: %Otel.API.InstrumentationScope{name: "my_lib"}
      },
      overrides
    )
  end

  defp view(opts), do: elem(Otel.SDK.Metrics.View.new(%{}, opts), 1)
  defp view!, do: elem(Otel.SDK.Metrics.View.new(), 1)

  describe "from_instrument/1" do
    test "carries instrument identity; view-specific fields default to nil" do
      inst = instrument()
      stream = Otel.SDK.Metrics.Stream.from_instrument(inst)

      assert stream.name == inst.name
      assert stream.description == inst.description
      assert stream.instrument == inst
      assert stream.attribute_keys == nil
      assert stream.aggregation == nil
      assert stream.exemplar_reservoir == nil
      assert stream.aggregation_cardinality_limit == nil
    end
  end

  describe "from_view/2 — view fields override instrument defaults" do
    test "name + description: view value wins; missing falls back to instrument value" do
      inst = instrument()

      named = Otel.SDK.Metrics.Stream.from_view(view(%{name: "renamed"}), inst)
      assert named.name == "renamed"
      assert named.description == "Request duration"

      with_desc = Otel.SDK.Metrics.Stream.from_view(view(%{description: "Custom"}), inst)
      assert with_desc.description == "Custom"

      empty = Otel.SDK.Metrics.Stream.from_view(view!(), inst)
      assert empty.name == "http.request.duration"
    end

    test "passes through view-only fields verbatim" do
      stream =
        Otel.SDK.Metrics.Stream.from_view(
          view(%{
            attribute_keys: {:include, ["method"]},
            aggregation: SomeAggregation,
            aggregation_options: %{boundaries: [1, 5, 10]},
            exemplar_reservoir: SomeReservoir,
            aggregation_cardinality_limit: 1000
          }),
          instrument()
        )

      assert stream.attribute_keys == {:include, ["method"]}
      assert stream.aggregation == SomeAggregation
      assert stream.aggregation_options == %{boundaries: [1, 5, 10]}
      assert stream.exemplar_reservoir == SomeReservoir
      assert stream.aggregation_cardinality_limit == 1000
    end
  end

  describe "resolve/1 — fills aggregation default and merges advisory boundaries" do
    test "nil aggregation resolves to the kind's default" do
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

    test "explicit aggregation from a view is preserved" do
      stream =
        Otel.SDK.Metrics.Stream.from_view(
          view(%{aggregation: Otel.SDK.Metrics.Aggregation.Drop}),
          instrument()
        )

      assert Otel.SDK.Metrics.Stream.resolve(stream).aggregation ==
               Otel.SDK.Metrics.Aggregation.Drop
    end

    # Advisory boundaries are only used when the View doesn't already
    # specify a non-default aggregation OR aggregation_options.
    test "advisory boundaries are picked up only when neither view aggregation nor opts override them" do
      inst = instrument(%{advisory: [explicit_bucket_boundaries: [1, 5, 10]]})

      # No view → advisory wins.
      assert Otel.SDK.Metrics.Stream.from_instrument(inst)
             |> Otel.SDK.Metrics.Stream.resolve()
             |> get_in([Access.key!(:aggregation_options), :boundaries]) == [1, 5, 10]

      # View boundaries take precedence over advisory.
      vp =
        Otel.SDK.Metrics.Stream.from_view(
          view(%{aggregation_options: %{boundaries: [100, 200]}}),
          inst
        )

      assert Otel.SDK.Metrics.Stream.resolve(vp).aggregation_options.boundaries == [100, 200]

      # View specifies a non-default aggregation → advisory ignored.
      sum =
        Otel.SDK.Metrics.Stream.from_view(
          view(%{aggregation: Otel.SDK.Metrics.Aggregation.Sum}),
          inst
        )

      refute Map.has_key?(Otel.SDK.Metrics.Stream.resolve(sum).aggregation_options, :boundaries)
    end
  end
end
