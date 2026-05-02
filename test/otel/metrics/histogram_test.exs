defmodule Otel.Metrics.HistogramTest do
  use ExUnit.Case, async: false

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    %{
      meter: Otel.Metrics.MeterProvider.get_meter(%Otel.InstrumentationScope{name: "test"})
    }
  end

  describe "create/3 — delegates to Meter.create_histogram" do
    test "with name only", %{meter: meter} do
      assert %Otel.Metrics.Instrument{kind: :histogram, name: "n"} =
               Otel.Metrics.Histogram.create(meter, "n")
    end

    test "forwards unit, description, and explicit_bucket_boundaries advisory", %{meter: meter} do
      boundaries = [0, 5, 10, 25, 50, 75, 100, 250, 500, 1000]

      assert %Otel.Metrics.Instrument{
               kind: :histogram,
               name: "n",
               unit: "ms",
               description: "duration",
               advisory: [explicit_bucket_boundaries: ^boundaries]
             } =
               Otel.Metrics.Histogram.create(meter, "n",
                 unit: "ms",
                 description: "duration",
                 advisory: [explicit_bucket_boundaries: boundaries]
               )
    end
  end

  test "record/3 returns :ok across value shapes and attributes", %{meter: meter} do
    inst = Otel.Metrics.Histogram.create(meter, "n")

    assert :ok = Otel.Metrics.Histogram.record(inst, 42)
    assert :ok = Otel.Metrics.Histogram.record(inst, 0)
    assert :ok = Otel.Metrics.Histogram.record(inst, 3.14)
    assert :ok = Otel.Metrics.Histogram.record(inst, 150, %{"http.method" => "POST"})
  end
end
