defmodule Otel.API.Metrics.GaugeTest do
  use ExUnit.Case, async: false

  setup do
    saved = :persistent_term.get({Otel.API.Metrics.MeterProvider, :global}, nil)
    :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})

    on_exit(fn ->
      if saved,
        do: :persistent_term.put({Otel.API.Metrics.MeterProvider, :global}, saved),
        else: :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})
    end)

    %{
      meter:
        Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{name: "test"})
    }
  end

  describe "create/3 — delegates to Meter.create_gauge" do
    test "with name only", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :gauge, name: "n"} =
               Otel.API.Metrics.Gauge.create(meter, "n")
    end

    test "forwards unit and description opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :gauge,
               name: "n",
               unit: "celsius",
               description: "CPU temperature"
             } =
               Otel.API.Metrics.Gauge.create(meter, "n",
                 unit: "celsius",
                 description: "CPU temperature"
               )
    end
  end

  test "enabled?/2 returns false under the Noop Meter", %{meter: meter} do
    inst = Otel.API.Metrics.Gauge.create(meter, "n")
    refute Otel.API.Metrics.Gauge.enabled?(inst)
    refute Otel.API.Metrics.Gauge.enabled?(inst, [])
  end

  # Spec L666-L668: Gauge value MAY be negative (point-in-time
  # measurements are bidirectional, unlike Counter).
  test "record/3 returns :ok across value shapes (incl. negative)", %{meter: meter} do
    inst = Otel.API.Metrics.Gauge.create(meter, "n")

    assert :ok = Otel.API.Metrics.Gauge.record(inst, 65)
    assert :ok = Otel.API.Metrics.Gauge.record(inst, 0)
    assert :ok = Otel.API.Metrics.Gauge.record(inst, -10)
    assert :ok = Otel.API.Metrics.Gauge.record(inst, 36.6)
    assert :ok = Otel.API.Metrics.Gauge.record(inst, 72.5, %{"cpu.id" => 0})
  end
end
