defmodule Otel.API.Metrics.CounterTest do
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
      meter: Otel.API.Metrics.MeterProvider.get_meter(%Otel.InstrumentationScope{name: "test"})
    }
  end

  describe "create/3 — delegates to Meter.create_counter" do
    test "with name only", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :counter, name: "n"} =
               Otel.API.Metrics.Counter.create(meter, "n")
    end

    test "forwards unit, description, and advisory opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :counter,
               name: "n",
               unit: "1",
               description: "desc",
               advisory: [explicit_bucket_boundaries: [10, 50]]
             } =
               Otel.API.Metrics.Counter.create(meter, "n",
                 unit: "1",
                 description: "desc",
                 advisory: [explicit_bucket_boundaries: [10, 50]]
               )
    end
  end

  test "enabled?/2 returns false under the Noop Meter", %{meter: meter} do
    inst = Otel.API.Metrics.Counter.create(meter, "n")
    refute Otel.API.Metrics.Counter.enabled?(inst)
    refute Otel.API.Metrics.Counter.enabled?(inst, span_name: "x")
  end

  test "add/3 returns :ok across value shapes and attribute payloads", %{meter: meter} do
    inst = Otel.API.Metrics.Counter.create(meter, "n")

    assert :ok = Otel.API.Metrics.Counter.add(inst, 1)
    assert :ok = Otel.API.Metrics.Counter.add(inst, 0)
    assert :ok = Otel.API.Metrics.Counter.add(inst, 1.5)
    assert :ok = Otel.API.Metrics.Counter.add(inst, 5, %{"http.method" => "GET"})
  end
end
