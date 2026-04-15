defmodule Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSizeTest do
  use ExUnit.Case, async: true

  defp ctx, do: Otel.API.Ctx.new()

  describe "new/1" do
    test "default size is 1" do
      state = Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{})
      assert state.size == 1
      assert state.count == 0
      assert state.exemplars == %{}
    end

    test "custom size" do
      state = Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 5})
      assert state.size == 5
    end
  end

  describe "offer/5" do
    test "stores first measurement" do
      state = Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 1})

      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.offer(
          state,
          42,
          1000,
          %{k: "v"},
          ctx()
        )

      assert state.count == 1
      assert map_size(state.exemplars) == 1
    end

    test "fills up to size" do
      state = Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 3})

      state =
        Enum.reduce(1..3, state, fn i, s ->
          Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.offer(s, i, 1000, %{}, ctx())
        end)

      assert state.count == 3
      assert map_size(state.exemplars) == 3
    end

    test "never exceeds size after many offers" do
      state = Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 2})

      state =
        Enum.reduce(1..100, state, fn i, s ->
          Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.offer(s, i, 1000, %{}, ctx())
        end)

      assert state.count == 100
      assert map_size(state.exemplars) == 2
    end
  end

  describe "collect/1" do
    test "returns exemplars and resets" do
      state = Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 2})

      state =
        Enum.reduce(1..2, state, fn i, s ->
          Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.offer(s, i, 1000, %{}, ctx())
        end)

      {exemplars, new_state} = Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.collect(state)
      assert length(exemplars) == 2
      assert new_state.count == 0
      assert new_state.exemplars == %{}
    end

    test "empty reservoir returns empty" do
      state = Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{})
      {exemplars, _} = Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.collect(state)
      assert exemplars == []
    end
  end
end
