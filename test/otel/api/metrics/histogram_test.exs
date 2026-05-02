defmodule Otel.API.Metrics.HistogramTest do
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

  describe "create/3 — delegates to Meter.create_histogram" do
    test "with name only", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :histogram, name: "n"} =
               Otel.API.Metrics.Histogram.create(meter, "n")
    end

    test "forwards unit, description, and explicit_bucket_boundaries advisory", %{meter: meter} do
      boundaries = [0, 5, 10, 25, 50, 75, 100, 250, 500, 1000]

      assert %Otel.API.Metrics.Instrument{
               kind: :histogram,
               name: "n",
               unit: "ms",
               description: "duration",
               advisory: [explicit_bucket_boundaries: ^boundaries]
             } =
               Otel.API.Metrics.Histogram.create(meter, "n",
                 unit: "ms",
                 description: "duration",
                 advisory: [explicit_bucket_boundaries: boundaries]
               )
    end
  end

  test "enabled?/2 returns false under the Noop Meter", %{meter: meter} do
    inst = Otel.API.Metrics.Histogram.create(meter, "n")
    refute Otel.API.Metrics.Histogram.enabled?(inst)
    refute Otel.API.Metrics.Histogram.enabled?(inst, [])
  end

  test "record/3 returns :ok across value shapes and attributes", %{meter: meter} do
    inst = Otel.API.Metrics.Histogram.create(meter, "n")

    assert :ok = Otel.API.Metrics.Histogram.record(inst, 42)
    assert :ok = Otel.API.Metrics.Histogram.record(inst, 0)
    assert :ok = Otel.API.Metrics.Histogram.record(inst, 3.14)
    assert :ok = Otel.API.Metrics.Histogram.record(inst, 150, %{"http.method" => "POST"})
  end
end
