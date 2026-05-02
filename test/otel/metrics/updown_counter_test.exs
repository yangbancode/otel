defmodule Otel.Metrics.UpDownCounterTest do
  use ExUnit.Case, async: false

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    %{
      meter: Otel.Metrics.MeterProvider.get_meter(%Otel.InstrumentationScope{name: "test"})
    }
  end

  describe "create/3 — delegates to Meter.create_up_down_counter" do
    test "with name only", %{meter: meter} do
      assert %Otel.Metrics.Instrument{kind: :updown_counter, name: "n"} =
               Otel.Metrics.UpDownCounter.create(meter, "n")
    end

    test "forwards unit and description opts", %{meter: meter} do
      assert %Otel.Metrics.Instrument{
               kind: :updown_counter,
               name: "n",
               unit: "1",
               description: "active requests"
             } =
               Otel.Metrics.UpDownCounter.create(meter, "n",
                 unit: "1",
                 description: "active requests"
               )
    end
  end

  # Spec L632-L634: UpDownCounter accepts negative values (the
  # bidirectional sibling of Counter).
  test "add/3 returns :ok across positive, negative, zero, float, and attrs", %{meter: meter} do
    inst = Otel.Metrics.UpDownCounter.create(meter, "n")

    assert :ok = Otel.Metrics.UpDownCounter.add(inst, 1)
    assert :ok = Otel.Metrics.UpDownCounter.add(inst, -1)
    assert :ok = Otel.Metrics.UpDownCounter.add(inst, 0)
    assert :ok = Otel.Metrics.UpDownCounter.add(inst, -0.5)
    assert :ok = Otel.Metrics.UpDownCounter.add(inst, 3, %{"http.method" => "GET"})
  end
end
