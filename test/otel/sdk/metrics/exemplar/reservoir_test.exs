defmodule Otel.SDK.Metrics.Exemplar.ReservoirTest do
  use ExUnit.Case, async: true

  defp reservoir_with_one_slot do
    {Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize,
     Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 1})}
  end

  describe "offer/6 — dispatch through the filter" do
    test "nil reservoir is a no-op" do
      assert Otel.SDK.Metrics.Exemplar.Reservoir.offer(nil, :always_on, 1, 0, %{}, %{}) == nil
    end

    test ":always_on filter forwards to the reservoir; :always_off skips" do
      assert {Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize, %{count: 1}} =
               Otel.SDK.Metrics.Exemplar.Reservoir.offer(
                 reservoir_with_one_slot(),
                 :always_on,
                 42,
                 1000,
                 %{},
                 %{}
               )

      assert {Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize, %{count: 0}} =
               Otel.SDK.Metrics.Exemplar.Reservoir.offer(
                 reservoir_with_one_slot(),
                 :always_off,
                 42,
                 1000,
                 %{},
                 %{}
               )
    end
  end

  describe "collect/1" do
    test "nil reservoir → {[], nil}" do
      assert {[], nil} = Otel.SDK.Metrics.Exemplar.Reservoir.collect(nil)
    end

    test "returns the offered exemplars and resets the reservoir state" do
      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 1})
        |> Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.offer(42, 1000, %{}, %{})

      assert {[exemplar], {_mod, %{count: 0}}} =
               Otel.SDK.Metrics.Exemplar.Reservoir.collect(
                 {Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize, state}
               )

      assert exemplar.value == 42
    end
  end
end
