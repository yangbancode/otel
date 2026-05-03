defmodule Otel.Metrics.ObservableGaugeTest do
  use ExUnit.Case, async: false

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    %{
      meter: Otel.Metrics.MeterProvider.get_meter()
    }
  end

  describe "create/3 — without callback" do
    test "with name only", %{meter: meter} do
      assert %Otel.Metrics.Instrument{kind: :observable_gauge, name: "n"} =
               Otel.Metrics.ObservableGauge.create(meter, "n")
    end

    test "forwards unit and description opts", %{meter: meter} do
      assert %Otel.Metrics.Instrument{
               kind: :observable_gauge,
               name: "n",
               unit: "celsius",
               description: "Room temperature"
             } =
               Otel.Metrics.ObservableGauge.create(meter, "n",
                 unit: "celsius",
                 description: "Room temperature"
               )
    end
  end

  describe "create/5 — with inline callback (spec L446-L447 MUST)" do
    test "attaches callback at creation time", %{meter: meter} do
      callback = fn _args -> [%Otel.Metrics.Measurement{value: 22.5, attributes: %{}}] end

      assert %Otel.Metrics.Instrument{kind: :observable_gauge, name: "n"} =
               Otel.Metrics.ObservableGauge.create(meter, "n", callback, nil, [])
    end

    test "forwards callback_args (spec L655-L658 SHOULD opaque state)", %{meter: meter} do
      callback = fn sensor_id ->
        [%Otel.Metrics.Measurement{value: 21.0, attributes: %{"sensor.id" => sensor_id}}]
      end

      assert %Otel.Metrics.Instrument{kind: :observable_gauge, unit: "celsius"} =
               Otel.Metrics.ObservableGauge.create(
                 meter,
                 "temperature",
                 callback,
                 "sensor-01",
                 unit: "celsius"
               )
    end
  end
end
