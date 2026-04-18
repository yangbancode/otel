defmodule Otel.API.Metrics.MeterTest do
  use ExUnit.Case

  setup do
    :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})
    meter = Otel.API.Metrics.MeterProvider.get_meter("test_lib")
    %{meter: meter}
  end

  describe "noop meter dispatch" do
    test "create_counter returns Instrument", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :counter, name: "my_counter"} =
               Otel.API.Metrics.Meter.create_counter(meter, "my_counter")
    end

    test "create_counter accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :counter,
               unit: "ms",
               description: "A counter"
             } =
               Otel.API.Metrics.Meter.create_counter(meter, "my_counter",
                 unit: "ms",
                 description: "A counter"
               )
    end

    test "create_histogram returns Instrument", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :histogram, name: "my_histogram"} =
               Otel.API.Metrics.Meter.create_histogram(meter, "my_histogram")
    end

    test "create_histogram accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :histogram, unit: "ms"} =
               Otel.API.Metrics.Meter.create_histogram(meter, "my_histogram",
                 unit: "ms",
                 description: "A histogram"
               )
    end

    test "create_gauge returns Instrument", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :gauge, name: "my_gauge"} =
               Otel.API.Metrics.Meter.create_gauge(meter, "my_gauge")
    end

    test "create_gauge accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :gauge, unit: "1"} =
               Otel.API.Metrics.Meter.create_gauge(meter, "my_gauge",
                 unit: "1",
                 description: "A gauge"
               )
    end

    test "create_updown_counter returns Instrument", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :updown_counter, name: "my_updown"} =
               Otel.API.Metrics.Meter.create_updown_counter(meter, "my_updown")
    end

    test "create_updown_counter accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :updown_counter, unit: "1"} =
               Otel.API.Metrics.Meter.create_updown_counter(meter, "my_updown",
                 unit: "1",
                 description: "An updown counter"
               )
    end

    test "create_observable_counter returns Instrument", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :observable_counter, name: "my_obs_counter"} =
               Otel.API.Metrics.Meter.create_observable_counter(meter, "my_obs_counter")
    end

    test "create_observable_counter accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :observable_counter,
               description: "An observable counter"
             } =
               Otel.API.Metrics.Meter.create_observable_counter(meter, "my_obs_counter",
                 description: "An observable counter"
               )
    end

    test "create_observable_counter with inline callback", %{meter: meter} do
      callback = fn _args -> [Otel.API.Metrics.Measurement.new(1)] end

      assert %Otel.API.Metrics.Instrument{kind: :observable_counter} =
               Otel.API.Metrics.Meter.create_observable_counter(
                 meter,
                 "my_obs_counter",
                 callback,
                 nil,
                 []
               )
    end

    test "create_observable_gauge returns Instrument", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge} =
               Otel.API.Metrics.Meter.create_observable_gauge(meter, "my_obs_gauge")
    end

    test "create_observable_gauge accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :observable_gauge,
               description: "An observable gauge"
             } =
               Otel.API.Metrics.Meter.create_observable_gauge(meter, "my_obs_gauge",
                 description: "An observable gauge"
               )
    end

    test "create_observable_gauge with inline callback", %{meter: meter} do
      callback = fn _args -> [Otel.API.Metrics.Measurement.new(1)] end

      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge} =
               Otel.API.Metrics.Meter.create_observable_gauge(
                 meter,
                 "my_obs_gauge",
                 callback,
                 nil,
                 []
               )
    end

    test "create_observable_updown_counter returns Instrument", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter} =
               Otel.API.Metrics.Meter.create_observable_updown_counter(
                 meter,
                 "my_obs_updown"
               )
    end

    test "create_observable_updown_counter accepts opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :observable_updown_counter,
               description: "An observable updown counter"
             } =
               Otel.API.Metrics.Meter.create_observable_updown_counter(
                 meter,
                 "my_obs_updown",
                 description: "An observable updown counter"
               )
    end

    test "create_observable_updown_counter with inline callback", %{meter: meter} do
      callback = fn _args -> [Otel.API.Metrics.Measurement.new(1)] end

      assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter} =
               Otel.API.Metrics.Meter.create_observable_updown_counter(
                 meter,
                 "my_obs_updown",
                 callback,
                 nil,
                 []
               )
    end

    test "record returns :ok", %{meter: meter} do
      instrument = Otel.API.Metrics.Meter.create_counter(meter, "my_counter")
      assert :ok == Otel.API.Metrics.Meter.record(instrument, 1)
    end

    test "record accepts attributes", %{meter: meter} do
      instrument = Otel.API.Metrics.Meter.create_counter(meter, "my_counter")
      assert :ok == Otel.API.Metrics.Meter.record(instrument, 1, %{"key" => "val"})
    end

    test "register_callback returns tagged registration handle", %{meter: meter} do
      callback = fn _args -> [] end
      registration = Otel.API.Metrics.Meter.register_callback(meter, [], callback, nil)
      assert {Otel.API.Metrics.Meter.Noop, :noop} = registration
    end

    test "register_callback accepts opts", %{meter: meter} do
      callback = fn _args -> [] end

      assert {Otel.API.Metrics.Meter.Noop, :noop} =
               Otel.API.Metrics.Meter.register_callback(meter, [], callback, nil, [])
    end

    test "unregister_callback is a no-op on noop registration", %{meter: meter} do
      callback = fn _args -> [] end
      registration = Otel.API.Metrics.Meter.register_callback(meter, [], callback, nil)
      assert :ok == Otel.API.Metrics.Meter.unregister_callback(registration)
    end

    test "enabled? returns false for noop", %{meter: meter} do
      instrument = Otel.API.Metrics.Meter.create_counter(meter, "my_counter")
      assert false == Otel.API.Metrics.Meter.enabled?(instrument)
    end

    test "enabled? accepts opts", %{meter: meter} do
      instrument = Otel.API.Metrics.Meter.create_counter(meter, "my_counter")
      assert false == Otel.API.Metrics.Meter.enabled?(instrument, [])
    end
  end
end
