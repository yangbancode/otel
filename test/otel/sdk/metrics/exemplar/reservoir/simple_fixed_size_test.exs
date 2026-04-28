defmodule Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSizeTest do
  use ExUnit.Case, async: true

  defp new_state(opts \\ %{}),
    do: Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(opts)

  defp offer(state, value),
    do: Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.offer(state, value, 1000, %{}, %{})

  describe "new/1" do
    test "default size is 1; explicit size overrides" do
      assert %{size: 1, count: 0, exemplars: %{}} = new_state()
      assert %{size: 5} = new_state(%{size: 5})
    end
  end

  describe "offer/5" do
    test "fills up to `size`; total `count` keeps incrementing past the cap" do
      state = Enum.reduce(1..100, new_state(%{size: 2}), &offer(&2, &1))

      assert state.count == 100
      # Reservoir never exceeds its capacity even under flood.
      assert map_size(state.exemplars) == 2
    end
  end

  describe "collect/1" do
    test "returns the offered exemplars and resets count + storage" do
      state = Enum.reduce(1..2, new_state(%{size: 2}), &offer(&2, &1))

      assert {[_, _], %{count: 0, exemplars: %{}}} =
               Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.collect(state)
    end

    test "empty reservoir → []" do
      assert {[], _} =
               Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.collect(new_state())
    end
  end
end
