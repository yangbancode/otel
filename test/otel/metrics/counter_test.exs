defmodule Otel.Metrics.CounterTest do
  use ExUnit.Case, async: false

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    %{
      meter: Otel.Metrics.MeterProvider.get_meter()
    }
  end

  describe "create/3 — delegates to Meter.create_counter" do
    test "with name only", %{meter: meter} do
      assert %Otel.Metrics.Instrument{kind: :counter, name: "n"} =
               Otel.Metrics.Counter.create(meter, "n")
    end

    test "forwards unit, description, and advisory opts", %{meter: meter} do
      assert %Otel.Metrics.Instrument{
               kind: :counter,
               name: "n",
               unit: "1",
               description: "desc",
               advisory: [explicit_bucket_boundaries: [10, 50]]
             } =
               Otel.Metrics.Counter.create(meter, "n",
                 unit: "1",
                 description: "desc",
                 advisory: [explicit_bucket_boundaries: [10, 50]]
               )
    end
  end

  test "add/3 returns :ok across value shapes and attribute payloads", %{meter: meter} do
    inst = Otel.Metrics.Counter.create(meter, "n")

    assert :ok = Otel.Metrics.Counter.add(inst, 1)
    assert :ok = Otel.Metrics.Counter.add(inst, 0)
    assert :ok = Otel.Metrics.Counter.add(inst, 1.5)
    assert :ok = Otel.Metrics.Counter.add(inst, 5, %{"http.method" => "GET"})
  end
end
