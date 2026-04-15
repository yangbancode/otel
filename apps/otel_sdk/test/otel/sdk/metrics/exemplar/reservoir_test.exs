defmodule Otel.SDK.Metrics.Exemplar.ReservoirTest do
  use ExUnit.Case, async: true

  describe "offer_to/6" do
    test "returns nil for nil reservoir" do
      assert nil ==
               Otel.SDK.Metrics.Exemplar.Reservoir.offer_to(
                 nil,
                 :always_on,
                 1,
                 0,
                 %{},
                 Otel.API.Ctx.new()
               )
    end

    test "offers when filter passes" do
      reservoir =
        {Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize,
         Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 1})}

      result =
        Otel.SDK.Metrics.Exemplar.Reservoir.offer_to(
          reservoir,
          :always_on,
          42,
          1000,
          %{},
          Otel.API.Ctx.new()
        )

      assert {Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize, state} = result
      assert state.count == 1
    end

    test "skips when filter rejects" do
      reservoir =
        {Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize,
         Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 1})}

      result =
        Otel.SDK.Metrics.Exemplar.Reservoir.offer_to(
          reservoir,
          :always_off,
          42,
          1000,
          %{},
          Otel.API.Ctx.new()
        )

      assert {Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize, state} = result
      assert state.count == 0
    end
  end

  describe "collect_from/1" do
    test "returns empty for nil reservoir" do
      assert {[], nil} == Otel.SDK.Metrics.Exemplar.Reservoir.collect_from(nil)
    end

    test "returns exemplars and resets state" do
      state = Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.new(%{size: 1})

      state =
        Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize.offer(
          state,
          42,
          1000,
          %{},
          Otel.API.Ctx.new()
        )

      reservoir = {Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize, state}

      {exemplars, {_mod, new_state}} = Otel.SDK.Metrics.Exemplar.Reservoir.collect_from(reservoir)
      assert length(exemplars) == 1
      assert hd(exemplars).value == 42
      assert new_state.count == 0
    end
  end
end
