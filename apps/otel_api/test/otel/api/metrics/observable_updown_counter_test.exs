defmodule Otel.API.Metrics.ObservableUpDownCounterTest do
  use ExUnit.Case

  setup do
    :persistent_term.erase({Otel.API.Metrics.MeterProvider, :global})
    meter = Otel.API.Metrics.MeterProvider.get_meter("test_lib")
    %{meter: meter}
  end

  describe "create/2,3 (without callback)" do
    test "creates observable updown counter via meter", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.ObservableUpDownCounter.create(meter, "process_heap_size")
    end

    test "accepts opts", %{meter: meter} do
      assert :ok ==
               Otel.API.Metrics.ObservableUpDownCounter.create(meter, "process_heap_size",
                 unit: "By",
                 description: "Process heap size"
               )
    end
  end

  describe "create/5 (with inline callback)" do
    test "creates observable updown counter with callback", %{meter: meter} do
      callback = fn _args -> [%Otel.API.Metrics.Measurement{value: 1024, attributes: %{}}] end

      assert :ok ==
               Otel.API.Metrics.ObservableUpDownCounter.create(
                 meter,
                 "heap_size",
                 callback,
                 nil,
                 []
               )
    end

    test "passes callback_args for state", %{meter: meter} do
      callback = fn pid ->
        [Otel.API.Metrics.Measurement.new(Process.info(pid, :heap_size) |> elem(1))]
      end

      assert :ok ==
               Otel.API.Metrics.ObservableUpDownCounter.create(
                 meter,
                 "heap_size",
                 callback,
                 self(),
                 unit: "words"
               )
    end
  end
end
