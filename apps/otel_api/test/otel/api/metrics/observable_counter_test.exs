defmodule Otel.API.Metrics.ObservableCounterTest do
  use ExUnit.Case

  setup do
    meter = Otel.API.Metrics.MeterProvider.get_meter("test_lib")
    %{meter: meter}
  end

  describe "create/2,3 (without callback)" do
    test "creates observable counter via meter", %{meter: meter} do
      assert :ok == Otel.API.Metrics.ObservableCounter.create(meter, "cpu_time")
    end

    test "accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.ObservableCounter.create(meter, "cpu_time",
                 unit: "s",
                 description: "CPU time per thread"
               )
    end
  end

  describe "create/5 (with inline callback)" do
    test "creates observable counter with callback", %{meter: meter} do
      callback = fn _args -> [{100, %{}}] end

      assert :ok ==
               Otel.API.Metrics.ObservableCounter.create(
                 meter,
                 "cpu_time",
                 callback,
                 nil,
                 []
               )
    end

    test "passes callback_args for state", %{meter: meter} do
      callback = fn pid -> [{Process.info(pid, :reductions) |> elem(1), %{}}] end

      assert :ok ==
               Otel.API.Metrics.ObservableCounter.create(
                 meter,
                 "reductions",
                 callback,
                 self(),
                 unit: "1",
                 description: "Process reductions"
               )
    end
  end
end
