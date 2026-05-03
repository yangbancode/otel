defmodule Otel.Metrics.ObservableGaugeTest do
  use ExUnit.Case, async: false

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    :ok
  end

  describe "create/3 — without callback" do
    test "with name only" do
      assert %Otel.Metrics.Instrument{kind: :observable_gauge, name: "n"} =
               Otel.Metrics.ObservableGauge.create("n")
    end

    test "forwards unit and description opts" do
      assert %Otel.Metrics.Instrument{
               kind: :observable_gauge,
               name: "n",
               unit: "celsius",
               description: "Room temperature"
             } =
               Otel.Metrics.ObservableGauge.create("n",
                 unit: "celsius",
                 description: "Room temperature"
               )
    end
  end

  describe "create/5 — with inline callback (spec L446-L447 MUST)" do
    test "attaches callback at creation time" do
      callback = fn _args -> [%Otel.Metrics.Measurement{value: 22.5, attributes: %{}}] end

      assert %Otel.Metrics.Instrument{kind: :observable_gauge, name: "n"} =
               Otel.Metrics.ObservableGauge.create("n", callback, nil, [])
    end

    test "forwards callback_args (spec L655-L658 SHOULD opaque state)" do
      callback = fn sensor_id ->
        [%Otel.Metrics.Measurement{value: 21.0, attributes: %{"sensor.id" => sensor_id}}]
      end

      assert %Otel.Metrics.Instrument{kind: :observable_gauge, unit: "celsius"} =
               Otel.Metrics.ObservableGauge.create(
                 "temperature",
                 callback,
                 "sensor-01",
                 unit: "celsius"
               )
    end
  end
end
