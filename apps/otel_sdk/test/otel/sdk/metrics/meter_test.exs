defmodule Otel.SDK.Metrics.MeterTest do
  use ExUnit.Case

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)

    {:ok, pid} = Otel.SDK.Metrics.MeterProvider.start_link(config: %{})
    {_module, meter_config} = Otel.SDK.Metrics.MeterProvider.get_meter(pid, "test_lib")
    meter = {Otel.SDK.Metrics.Meter, meter_config}

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{meter: meter}
  end

  describe "instrument creation" do
    test "create_counter returns :ok", %{meter: meter} do
      assert :ok == Otel.SDK.Metrics.Meter.create_counter(meter, "counter", [])
    end

    test "create_histogram returns :ok", %{meter: meter} do
      assert :ok == Otel.SDK.Metrics.Meter.create_histogram(meter, "histogram", [])
    end

    test "create_gauge returns :ok", %{meter: meter} do
      assert :ok == Otel.SDK.Metrics.Meter.create_gauge(meter, "gauge", [])
    end

    test "create_updown_counter returns :ok", %{meter: meter} do
      assert :ok == Otel.SDK.Metrics.Meter.create_updown_counter(meter, "updown", [])
    end

    test "create_observable_counter returns :ok", %{meter: meter} do
      assert :ok == Otel.SDK.Metrics.Meter.create_observable_counter(meter, "obs_counter", [])
    end

    test "create_observable_counter with callback returns :ok", %{meter: meter} do
      callback = fn _args -> [{1, %{}}] end

      assert :ok ==
               Otel.SDK.Metrics.Meter.create_observable_counter(
                 meter,
                 "obs_counter",
                 callback,
                 nil,
                 []
               )
    end

    test "create_observable_gauge returns :ok", %{meter: meter} do
      assert :ok == Otel.SDK.Metrics.Meter.create_observable_gauge(meter, "obs_gauge", [])
    end

    test "create_observable_gauge with callback returns :ok", %{meter: meter} do
      callback = fn _args -> [{1, %{}}] end

      assert :ok ==
               Otel.SDK.Metrics.Meter.create_observable_gauge(
                 meter,
                 "obs_gauge",
                 callback,
                 nil,
                 []
               )
    end

    test "create_observable_updown_counter returns :ok", %{meter: meter} do
      assert :ok ==
               Otel.SDK.Metrics.Meter.create_observable_updown_counter(meter, "obs_updown", [])
    end

    test "create_observable_updown_counter with callback returns :ok", %{meter: meter} do
      callback = fn _args -> [{1, %{}}] end

      assert :ok ==
               Otel.SDK.Metrics.Meter.create_observable_updown_counter(
                 meter,
                 "obs_updown",
                 callback,
                 nil,
                 []
               )
    end
  end

  describe "recording" do
    test "record returns :ok", %{meter: meter} do
      assert :ok == Otel.SDK.Metrics.Meter.record(meter, "counter", 1, %{})
    end
  end

  describe "callback registration" do
    test "register_callback returns :ok", %{meter: meter} do
      callback = fn _args -> [] end
      assert :ok == Otel.SDK.Metrics.Meter.register_callback(meter, [], callback, nil, [])
    end
  end

  describe "enabled?" do
    test "returns true for SDK meter", %{meter: meter} do
      assert true == Otel.SDK.Metrics.Meter.enabled?(meter, [])
    end
  end
end
