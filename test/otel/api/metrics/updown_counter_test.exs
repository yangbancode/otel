defmodule Otel.API.Metrics.UpDownCounterTest do
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

  describe "create/3 — delegates to Meter.create_up_down_counter" do
    test "with name only", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :updown_counter, name: "n"} =
               Otel.API.Metrics.UpDownCounter.create(meter, "n")
    end

    test "forwards unit and description opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :updown_counter,
               name: "n",
               unit: "1",
               description: "active requests"
             } =
               Otel.API.Metrics.UpDownCounter.create(meter, "n",
                 unit: "1",
                 description: "active requests"
               )
    end
  end

  test "enabled?/2 returns false under the Noop Meter", %{meter: meter} do
    inst = Otel.API.Metrics.UpDownCounter.create(meter, "n")
    refute Otel.API.Metrics.UpDownCounter.enabled?(inst)
    refute Otel.API.Metrics.UpDownCounter.enabled?(inst, [])
  end

  # Spec L632-L634: UpDownCounter accepts negative values (the
  # bidirectional sibling of Counter).
  test "add/3 returns :ok across positive, negative, zero, float, and attrs", %{meter: meter} do
    inst = Otel.API.Metrics.UpDownCounter.create(meter, "n")

    assert :ok = Otel.API.Metrics.UpDownCounter.add(inst, 1)
    assert :ok = Otel.API.Metrics.UpDownCounter.add(inst, -1)
    assert :ok = Otel.API.Metrics.UpDownCounter.add(inst, 0)
    assert :ok = Otel.API.Metrics.UpDownCounter.add(inst, -0.5)
    assert :ok = Otel.API.Metrics.UpDownCounter.add(inst, 3, %{"http.method" => "GET"})
  end
end
