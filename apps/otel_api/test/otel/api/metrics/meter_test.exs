defmodule Otel.API.Metrics.MeterTest do
  use ExUnit.Case

  setup do
    meter = Otel.API.Metrics.MeterProvider.get_meter("test_lib")
    %{meter: meter}
  end

  describe "noop meter dispatch" do
    test "create_counter returns :ok", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Meter.create_counter(meter, "my_counter")
    end

    test "create_counter accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Meter.create_counter(meter, "my_counter",
                 unit: "ms",
                 description: "A counter"
               )
    end

    test "create_histogram returns :ok", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Meter.create_histogram(meter, "my_histogram")
    end

    test "create_histogram accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Meter.create_histogram(meter, "my_histogram",
                 unit: "ms",
                 description: "A histogram"
               )
    end

    test "create_gauge returns :ok", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Meter.create_gauge(meter, "my_gauge")
    end

    test "create_gauge accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Meter.create_gauge(meter, "my_gauge",
                 unit: "1",
                 description: "A gauge"
               )
    end

    test "create_updown_counter returns :ok", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Meter.create_updown_counter(meter, "my_updown")
    end

    test "create_updown_counter accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Meter.create_updown_counter(meter, "my_updown",
                 unit: "1",
                 description: "An updown counter"
               )
    end

    test "create_observable_counter returns :ok", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Meter.create_observable_counter(meter, "my_obs_counter")
    end

    test "create_observable_counter accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Meter.create_observable_counter(meter, "my_obs_counter",
                 description: "An observable counter"
               )
    end

    test "create_observable_counter with inline callback", %{meter: meter} do
      callback = fn _args -> [{1, %{}}] end

      assert :ok ==
               Otel.API.Metrics.Meter.create_observable_counter(
                 meter,
                 "my_obs_counter",
                 callback,
                 nil,
                 []
               )
    end

    test "create_observable_gauge returns :ok", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Meter.create_observable_gauge(meter, "my_obs_gauge")
    end

    test "create_observable_gauge accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Meter.create_observable_gauge(meter, "my_obs_gauge",
                 description: "An observable gauge"
               )
    end

    test "create_observable_gauge with inline callback", %{meter: meter} do
      callback = fn _args -> [{1, %{}}] end

      assert :ok ==
               Otel.API.Metrics.Meter.create_observable_gauge(
                 meter,
                 "my_obs_gauge",
                 callback,
                 nil,
                 []
               )
    end

    test "create_observable_updown_counter returns :ok", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Meter.create_observable_updown_counter(
                 meter,
                 "my_obs_updown"
               )
    end

    test "create_observable_updown_counter accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Meter.create_observable_updown_counter(
                 meter,
                 "my_obs_updown",
                 description: "An observable updown counter"
               )
    end

    test "create_observable_updown_counter with inline callback", %{meter: meter} do
      callback = fn _args -> [{1, %{}}] end

      assert :ok ==
               Otel.API.Metrics.Meter.create_observable_updown_counter(
                 meter,
                 "my_obs_updown",
                 callback,
                 nil,
                 []
               )
    end

    test "record returns :ok", %{meter: meter} do
      assert :ok == Otel.API.Metrics.Meter.record(meter, "my_counter", 1)
    end

    test "record accepts attributes", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.Meter.record(meter, "my_counter", 1, [
                 Otel.API.Common.Attribute.new("key", Otel.API.Common.AnyValue.string("val"))
               ])
    end

    test "register_callback returns :ok", %{meter: meter} do
      callback = fn _args -> [] end
      assert :ok == Otel.API.Metrics.Meter.register_callback(meter, [], callback, nil)
    end

    test "register_callback accepts opts", %{meter: meter} do
      callback = fn _args -> [] end
      assert :ok == Otel.API.Metrics.Meter.register_callback(meter, [], callback, nil, [])
    end

    test "enabled? returns false for noop", %{meter: meter} do
      assert false == Otel.API.Metrics.Meter.enabled?(meter)
    end

    test "enabled? accepts opts", %{meter: meter} do
      assert false == Otel.API.Metrics.Meter.enabled?(meter, [])
    end
  end
end
