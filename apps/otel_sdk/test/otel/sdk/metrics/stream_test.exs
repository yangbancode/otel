defmodule Otel.SDK.Metrics.StreamTest do
  use ExUnit.Case, async: true

  defp instrument(overrides \\ %{}) do
    Map.merge(
      %Otel.SDK.Metrics.Instrument{
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

    test "uses advisory attributes when present" do
      inst = instrument(%{advisory: [attributes: [:method, :status]]})
      stream = Otel.SDK.Metrics.Stream.from_instrument(inst)
      assert stream.attribute_keys == {:include, [:method, :status]}
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
      {:ok, view} = Otel.SDK.Metrics.View.new(%{}, %{attribute_keys: {:include, [:method]}})
      stream = Otel.SDK.Metrics.Stream.from_view(view, instrument())
      assert stream.attribute_keys == {:include, [:method]}
    end

    test "falls back to advisory attributes" do
      {:ok, view} = Otel.SDK.Metrics.View.new()
      inst = instrument(%{advisory: [attributes: [:method]]})
      stream = Otel.SDK.Metrics.Stream.from_view(view, inst)
      assert stream.attribute_keys == {:include, [:method]}
    end

    test "no attribute_keys and no advisory leaves nil" do
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
end
