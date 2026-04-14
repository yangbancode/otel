defmodule Otel.API.Metrics.ObservableGaugeTest do
  use ExUnit.Case

  setup do
    meter = Otel.API.Metrics.MeterProvider.get_meter("test_lib")
    %{meter: meter}
  end

  describe "create/2,3 (without callback)" do
    test "creates observable gauge via meter", %{meter: meter} do
      assert :ok == Otel.API.Metrics.ObservableGauge.create(meter, "room_temperature")
    end

    test "accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.ObservableGauge.create(meter, "room_temperature",
                 unit: "celsius",
                 description: "Room temperature reading"
               )
    end
  end

  describe "create/5 (with inline callback)" do
    test "creates observable gauge with callback", %{meter: meter} do
      callback = fn _args -> [{22.5, %{}}] end

      assert :ok ==
               Otel.API.Metrics.ObservableGauge.create(
                 meter,
                 "room_temperature",
                 callback,
                 nil,
                 []
               )
    end

    test "passes callback_args for state", %{meter: meter} do
      callback = fn sensor_id -> [{21.0, %{"sensor.id" => sensor_id}}] end

      assert :ok ==
               Otel.API.Metrics.ObservableGauge.create(
                 meter,
                 "temperature",
                 callback,
                 "sensor-01",
                 unit: "celsius"
               )
    end
  end
end
