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

  describe "from_instrument/1" do
    test "creates stream with instrument defaults" do
      inst = instrument()
      stream = Otel.SDK.Metrics.Stream.from_instrument(inst)

      assert stream.name == "http.request.duration"
      assert stream.description == "Request duration"
      assert stream.instrument == inst
      assert stream.attribute_keys == nil
      assert stream.aggregation == nil
      assert stream.exemplar_reservoir == nil
      assert stream.aggregation_cardinality_limit == nil
    end

  end

  describe "from_view/2" do
    test "uses view name when configured" do
      {:ok, view} =
        Otel.SDK.Metrics.View.new(
          %{name: "http.request.duration"},
          %{name: "http.duration"}
        )

      stream = Otel.SDK.Metrics.Stream.from_view(view, instrument())
      assert stream.name == "http.duration"
    end

    test "falls back to instrument name" do
      {:ok, view} = Otel.SDK.Metrics.View.new()
      stream = Otel.SDK.Metrics.Stream.from_view(view, instrument())
      assert stream.name == "http.request.duration"
    end

    test "uses view description when configured" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{}, %{description: "Custom"})
      stream = Otel.SDK.Metrics.Stream.from_view(view, instrument())
      assert stream.description == "Custom"
    end

    test "falls back to instrument description" do
      {:ok, view} = Otel.SDK.Metrics.View.new()
      stream = Otel.SDK.Metrics.Stream.from_view(view, instrument())
      assert stream.description == "Request duration"
    end

    test "uses view attribute_keys when configured" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{}, %{attribute_keys: {:include, ["method"]}})
      stream = Otel.SDK.Metrics.Stream.from_view(view, instrument())
      assert stream.attribute_keys == {:include, ["method"]}
    end

    test "no attribute_keys leaves nil" do
      {:ok, view} = Otel.SDK.Metrics.View.new()
      stream = Otel.SDK.Metrics.Stream.from_view(view, instrument())
      assert stream.attribute_keys == nil
    end

    test "passes through aggregation config" do
      {:ok, view} =
        Otel.SDK.Metrics.View.new(%{}, %{
          aggregation: SomeAggregation,
          aggregation_options: %{boundaries: [1, 5, 10]}
        })

      stream = Otel.SDK.Metrics.Stream.from_view(view, instrument())
      assert stream.aggregation == SomeAggregation
      assert stream.aggregation_options == %{boundaries: [1, 5, 10]}
    end

    test "passes through exemplar_reservoir config" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{}, %{exemplar_reservoir: SomeReservoir})
      stream = Otel.SDK.Metrics.Stream.from_view(view, instrument())
      assert stream.exemplar_reservoir == SomeReservoir
    end

    test "passes through aggregation_cardinality_limit" do
      {:ok, view} = Otel.SDK.Metrics.View.new(%{}, %{aggregation_cardinality_limit: 1000})
      stream = Otel.SDK.Metrics.Stream.from_view(view, instrument())
      assert stream.aggregation_cardinality_limit == 1000
    end

    test "stores reference to source instrument" do
      {:ok, view} = Otel.SDK.Metrics.View.new()
      inst = instrument()
      stream = Otel.SDK.Metrics.Stream.from_view(view, inst)
      assert stream.instrument == inst
    end
  end

  describe "resolve/1" do
    test "resolves nil aggregation to default for counter" do
      inst = instrument(%{kind: :counter})
      stream = Otel.SDK.Metrics.Stream.from_instrument(inst)
      resolved = Otel.SDK.Metrics.Stream.resolve(stream)
      assert resolved.aggregation == Otel.SDK.Metrics.Aggregation.Sum
    end

    test "resolves nil aggregation to default for gauge" do
      inst = instrument(%{kind: :gauge})
      stream = Otel.SDK.Metrics.Stream.from_instrument(inst)
      resolved = Otel.SDK.Metrics.Stream.resolve(stream)
      assert resolved.aggregation == Otel.SDK.Metrics.Aggregation.LastValue
    end

    test "resolves nil aggregation to default for histogram" do
      stream = Otel.SDK.Metrics.Stream.from_instrument(instrument())
      resolved = Otel.SDK.Metrics.Stream.resolve(stream)
      assert resolved.aggregation == Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram
    end

    test "preserves explicit aggregation" do
      {:ok, view} =
        Otel.SDK.Metrics.View.new(%{}, %{aggregation: Otel.SDK.Metrics.Aggregation.Drop})

      stream = Otel.SDK.Metrics.Stream.from_view(view, instrument())
      resolved = Otel.SDK.Metrics.Stream.resolve(stream)
      assert resolved.aggregation == Otel.SDK.Metrics.Aggregation.Drop
    end

    test "merges advisory bucket boundaries into opts" do
      inst = instrument(%{advisory: [explicit_bucket_boundaries: [1, 5, 10]]})
      stream = Otel.SDK.Metrics.Stream.from_instrument(inst)
      resolved = Otel.SDK.Metrics.Stream.resolve(stream)
      assert resolved.aggregation_options.boundaries == [1, 5, 10]
    end

    test "view aggregation_options take precedence over advisory" do
      inst = instrument(%{advisory: [explicit_bucket_boundaries: [1, 5, 10]]})

      {:ok, view} =
        Otel.SDK.Metrics.View.new(%{}, %{aggregation_options: %{boundaries: [100, 200]}})

      stream = Otel.SDK.Metrics.Stream.from_view(view, inst)
      resolved = Otel.SDK.Metrics.Stream.resolve(stream)
      assert resolved.aggregation_options.boundaries == [100, 200]
    end

    test "view specifying EBH aggregation without boundaries ignores advisory" do
      inst = instrument(%{advisory: [explicit_bucket_boundaries: [1, 5, 10]]})

      {:ok, view} =
        Otel.SDK.Metrics.View.new(%{}, %{
          aggregation: Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram
        })

      stream = Otel.SDK.Metrics.Stream.from_view(view, inst)
      resolved = Otel.SDK.Metrics.Stream.resolve(stream)
      refute Map.has_key?(resolved.aggregation_options, :boundaries)
    end

    test "view specifying non-default aggregation ignores advisory boundaries" do
      inst = instrument(%{advisory: [explicit_bucket_boundaries: [1, 5, 10]]})

      {:ok, view} =
        Otel.SDK.Metrics.View.new(%{}, %{aggregation: Otel.SDK.Metrics.Aggregation.Sum})

      stream = Otel.SDK.Metrics.Stream.from_view(view, inst)
      resolved = Otel.SDK.Metrics.Stream.resolve(stream)
      refute Map.has_key?(resolved.aggregation_options, :boundaries)
    end

    test "no view uses advisory boundaries as fallback" do
      inst = instrument(%{advisory: [explicit_bucket_boundaries: [1, 5, 10]]})
      stream = Otel.SDK.Metrics.Stream.from_instrument(inst)
      resolved = Otel.SDK.Metrics.Stream.resolve(stream)
      assert resolved.aggregation_options.boundaries == [1, 5, 10]
    end

    test "view with default aggregation uses advisory boundaries" do
      inst = instrument(%{advisory: [explicit_bucket_boundaries: [1, 5, 10]]})
      {:ok, view} = Otel.SDK.Metrics.View.new(%{name: "http.request.duration"}, %{})
      stream = Otel.SDK.Metrics.Stream.from_view(view, inst)
      resolved = Otel.SDK.Metrics.Stream.resolve(stream)
      assert resolved.aggregation_options.boundaries == [1, 5, 10]
    end
  end
end
