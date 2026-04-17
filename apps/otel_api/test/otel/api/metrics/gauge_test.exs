defmodule Otel.API.Metrics.GaugeTest do
  use ExUnit.Case

  setup do
    meter = Otel.API.Metrics.MeterProvider.get_meter("test_lib")
    %{meter: meter}
  end

  describe "create/2,3" do
    test "creates gauge via meter", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Gauge.create(meter, "cpu_temperature")
    end

    test "accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Gauge.create(meter, "cpu_temperature",
                 unit: "celsius",
                 description: "CPU temperature"
               )
    end
  end

  describe "enabled?/1,2" do
    test "returns false for noop", %{meter: meter} do
      assert false == Otel.API.Metrics.Gauge.enabled?(meter)
    end

    test "accepts opts", %{meter: meter} do
      assert false == Otel.API.Metrics.Gauge.enabled?(meter, [])
    end
  end

  describe "record/3,4" do
    test "records a value", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Gauge.record(meter, "cpu_temperature", 65)
    end

    test "records with attributes", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Gauge.record(meter, "cpu_temperature", 72.5, [
                 Otel.API.Common.Attribute.new("cpu.id", Otel.API.Common.AnyValue.int(0))
               ])
    end

    test "accepts negative value", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Gauge.record(meter, "temperature", -10)
    end

    test "accepts zero", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Gauge.record(meter, "temperature", 0)
    end

    test "accepts float", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Gauge.record(meter, "temperature", 36.6)
    end
  end
end
