defmodule Otel.API.PropagatorTest do
  use ExUnit.Case, async: false

  setup do
    :persistent_term.erase(:"__otel.propagator.text_map__")
    :ok
  end

  describe "get/set_text_map_propagator" do
    test "returns nil by default" do
      assert Otel.API.Propagator.get_text_map_propagator() == nil
    end

    test "sets and gets propagator module" do
      Otel.API.Propagator.set_text_map_propagator(Otel.API.Propagator.TraceContext)
      assert Otel.API.Propagator.get_text_map_propagator() == Otel.API.Propagator.TraceContext
    end

    test "sets and gets propagator tuple" do
      propagator = {Otel.API.Propagator.TextMap.Composite, [Otel.API.Propagator.TraceContext]}
      Otel.API.Propagator.set_text_map_propagator(propagator)
      assert Otel.API.Propagator.get_text_map_propagator() == propagator
    end
  end
end
