defmodule Otel.API.Metrics.ObservableGaugeTest do
  use ExUnit.Case

  setup do
    :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})

    meter =
      Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{name: "test_lib"})

    %{meter: meter}
  end

  describe "create/2,3 (without callback)" do
    test "creates observable gauge via meter", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge, name: "room_temperature"} =
               Otel.API.Metrics.ObservableGauge.create(meter, "room_temperature")
    end

    test "accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :observable_gauge,
               unit: "celsius",
               description: "Room temperature reading"
             } =
               Otel.API.Metrics.ObservableGauge.create(meter, "room_temperature",
                 unit: "celsius",
                 description: "Room temperature reading"
               )
    end
  end

  describe "create/5 (with inline callback)" do
    test "creates observable gauge with callback", %{meter: meter} do
      callback = fn _args -> [%Otel.API.Metrics.Measurement{value: 22.5, attributes: %{}}] end

      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge} =
               Otel.API.Metrics.ObservableGauge.create(
                 meter,
                 "room_temperature",
                 callback,
                 nil,
                 []
               )
    end

    test "passes callback_args for state", %{meter: meter} do
      callback = fn sensor_id ->
        [%Otel.API.Metrics.Measurement{value: 21.0, attributes: %{"sensor.id" => sensor_id}}]
      end

      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge, unit: "celsius"} =
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
