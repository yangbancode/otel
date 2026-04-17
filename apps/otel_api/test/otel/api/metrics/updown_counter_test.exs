defmodule Otel.API.Metrics.UpDownCounterTest do
  use ExUnit.Case

  setup do
    meter = Otel.API.Metrics.MeterProvider.get_meter("test_lib")
    %{meter: meter}
  end

  describe "create/2,3" do
    test "creates updown_counter via meter", %{meter: meter} do
      assert :ok == Otel.API.Metrics.UpDownCounter.create(meter, "active_requests")
    end

    test "accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.UpDownCounter.create(meter, "active_requests",
                 unit: "1",
                 description: "Number of active requests"
               )
    end
  end

  describe "enabled?/1,2" do
    test "returns false for noop", %{meter: meter} do
      assert false == Otel.API.Metrics.UpDownCounter.enabled?(meter)
    end

    test "accepts opts", %{meter: meter} do
      assert false == Otel.API.Metrics.UpDownCounter.enabled?(meter, [])
    end
  end

  describe "add/3,4" do
    test "records a positive value", %{meter: meter} do
      assert :ok == Otel.API.Metrics.UpDownCounter.add(meter, "active_requests", 1)
    end

    test "records a negative value", %{meter: meter} do
      assert :ok == Otel.API.Metrics.UpDownCounter.add(meter, "active_requests", -1)
    end

    test "records with attributes", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.UpDownCounter.add(meter, "active_requests", 3, [
                 Otel.API.Common.Attribute.new(
                   "http.method",
                   Otel.API.Common.AnyValue.string("GET")
                 )
               ])
    end

    test "accepts zero", %{meter: meter} do
      assert :ok == Otel.API.Metrics.UpDownCounter.add(meter, "active_requests", 0)
    end

    test "accepts float", %{meter: meter} do
      assert :ok == Otel.API.Metrics.UpDownCounter.add(meter, "active_requests", -0.5)
    end
  end
end
