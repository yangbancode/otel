defmodule Otel.API.Metrics.GaugeTest do
  use ExUnit.Case

  setup do
    :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})
    meter = Otel.API.Metrics.MeterProvider.get_meter("test_lib")
    %{meter: meter}
  end

  describe "create/2,3" do
    test "creates gauge via meter", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :gauge, name: "cpu_temperature"} =
               Otel.API.Metrics.Gauge.create(meter, "cpu_temperature")
    end

    test "accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :gauge,
               unit: "celsius",
               description: "CPU temperature"
             } =
               Otel.API.Metrics.Gauge.create(meter, "cpu_temperature",
                 unit: "celsius",
                 description: "CPU temperature"
               )
    end
  end

  describe "enabled?/1,2" do
    test "returns false for noop", %{meter: meter} do
      instrument = Otel.API.Metrics.Gauge.create(meter, "cpu_temperature")
      assert false == Otel.API.Metrics.Gauge.enabled?(instrument)
    end

    test "accepts opts", %{meter: meter} do
      instrument = Otel.API.Metrics.Gauge.create(meter, "cpu_temperature")
      assert false == Otel.API.Metrics.Gauge.enabled?(instrument, [])
    end
  end

  describe "record/2,3" do
    test "records a value", %{meter: meter} do
      instrument = Otel.API.Metrics.Gauge.create(meter, "cpu_temperature")
      assert :ok == Otel.API.Metrics.Gauge.record(instrument, 65)
    end

    test "records with attributes", %{meter: meter} do
      instrument = Otel.API.Metrics.Gauge.create(meter, "cpu_temperature")

      assert :ok ==
               Otel.API.Metrics.Gauge.record(instrument, 72.5, %{"cpu.id" => 0})
    end

    test "accepts negative value", %{meter: meter} do
      instrument = Otel.API.Metrics.Gauge.create(meter, "temperature")
      assert :ok == Otel.API.Metrics.Gauge.record(instrument, -10)
    end

    test "accepts zero", %{meter: meter} do
      instrument = Otel.API.Metrics.Gauge.create(meter, "temperature")
      assert :ok == Otel.API.Metrics.Gauge.record(instrument, 0)
    end

    test "accepts float", %{meter: meter} do
      instrument = Otel.API.Metrics.Gauge.create(meter, "temperature")
      assert :ok == Otel.API.Metrics.Gauge.record(instrument, 36.6)
    end
  end
end
