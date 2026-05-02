defmodule Otel.SDK.Config.SelectorTest do
  use ExUnit.Case, async: true

  describe "propagator/1" do
    test "implemented atoms map to project modules; custom modules pass through" do
      assert Otel.SDK.Config.Selector.propagator(:tracecontext) ==
               Otel.API.Propagator.TextMap.TraceContext

      assert Otel.SDK.Config.Selector.propagator(:baggage) ==
               Otel.API.Propagator.TextMap.Baggage

      assert Otel.SDK.Config.Selector.propagator(:none) ==
               Otel.API.Propagator.TextMap.Noop

      assert Otel.SDK.Config.Selector.propagator(MyApp.CustomPropagator) ==
               MyApp.CustomPropagator
    end

    test "spec-known but unimplemented propagators raise ArgumentError" do
      for unimpl <- [:b3, :b3multi, :jaeger, :xray, :ottrace] do
        assert_raise ArgumentError, ~r/not implemented in this SDK/, fn ->
          Otel.SDK.Config.Selector.propagator(unimpl)
        end
      end
    end
  end
end
