defmodule Otel.API.Metrics.ObservableGaugeTest do
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

  describe "create/3 — without callback" do
    test "with name only", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge, name: "n"} =
               Otel.API.Metrics.ObservableGauge.create(meter, "n")
    end

    test "forwards unit and description opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :observable_gauge,
               name: "n",
               unit: "celsius",
               description: "Room temperature"
             } =
               Otel.API.Metrics.ObservableGauge.create(meter, "n",
                 unit: "celsius",
                 description: "Room temperature"
               )
    end
  end

  describe "create/5 — with inline callback (spec L446-L447 MUST)" do
    test "attaches callback at creation time", %{meter: meter} do
      callback = fn _args -> [%Otel.API.Metrics.Measurement{value: 22.5, attributes: %{}}] end

      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge, name: "n"} =
               Otel.API.Metrics.ObservableGauge.create(meter, "n", callback, nil, [])
    end

    test "forwards callback_args (spec L655-L658 SHOULD opaque state)", %{meter: meter} do
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
