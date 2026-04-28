defmodule Otel.API.Metrics.ObservableUpDownCounterTest do
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
      meter:
        Otel.API.Metrics.MeterProvider.get_meter(%Otel.API.InstrumentationScope{name: "test"})
    }
  end

  describe "create/3 — without callback" do
    test "with name only", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter, name: "n"} =
               Otel.API.Metrics.ObservableUpDownCounter.create(meter, "n")
    end

    test "forwards unit and description opts", %{meter: meter} do
      assert %Otel.API.Metrics.Instrument{
               kind: :observable_updown_counter,
               name: "n",
               unit: "By",
               description: "Process heap size"
             } =
               Otel.API.Metrics.ObservableUpDownCounter.create(meter, "n",
                 unit: "By",
                 description: "Process heap size"
               )
    end
  end

  describe "create/5 — with inline callback (spec L446-L447 MUST)" do
    test "attaches callback at creation time", %{meter: meter} do
      callback = fn _args -> [%Otel.API.Metrics.Measurement{value: 1024, attributes: %{}}] end

      assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter, name: "n"} =
               Otel.API.Metrics.ObservableUpDownCounter.create(meter, "n", callback, nil, [])
    end

    test "forwards callback_args (spec L655-L658 SHOULD opaque state)", %{meter: meter} do
      callback = fn pid ->
        {:heap_size, n} = Process.info(pid, :heap_size)
        [%Otel.API.Metrics.Measurement{value: n, attributes: %{}}]
      end

      assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter, unit: "words"} =
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
