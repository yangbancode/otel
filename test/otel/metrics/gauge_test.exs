defmodule Otel.Metrics.GaugeTest do
  use ExUnit.Case, async: false

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    %{
      meter: Otel.Metrics.MeterProvider.get_meter()
    }
  end

  describe "create/3 — delegates to Meter.create_gauge" do
    test "with name only", %{meter: meter} do
      assert %Otel.Metrics.Instrument{kind: :gauge, name: "n"} =
               Otel.Metrics.Gauge.create(meter, "n")
    end

    test "forwards unit and description opts", %{meter: meter} do
      assert %Otel.Metrics.Instrument{
               kind: :gauge,
               name: "n",
               unit: "celsius",
               description: "CPU temperature"
             } =
               Otel.Metrics.Gauge.create(meter, "n",
                 unit: "celsius",
                 description: "CPU temperature"
               )
    end
  end

  # Spec L666-L668: Gauge value MAY be negative (point-in-time
  # measurements are bidirectional, unlike Counter).
  test "record/3 returns :ok across value shapes (incl. negative)", %{meter: meter} do
    inst = Otel.Metrics.Gauge.create(meter, "n")

    assert :ok = Otel.Metrics.Gauge.record(inst, 65)
    assert :ok = Otel.Metrics.Gauge.record(inst, 0)
    assert :ok = Otel.Metrics.Gauge.record(inst, -10)
    assert :ok = Otel.Metrics.Gauge.record(inst, 36.6)
    assert :ok = Otel.Metrics.Gauge.record(inst, 72.5, %{"cpu.id" => 0})
  end
end
