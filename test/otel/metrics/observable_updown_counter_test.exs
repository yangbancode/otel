defmodule Otel.Metrics.ObservableUpDownCounterTest do
  use ExUnit.Case, async: false

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    :ok
  end

  describe "create/3 — without callback" do
    test "with name only" do
      assert %Otel.Metrics.Instrument{kind: :observable_updown_counter, name: "n"} =
               Otel.Metrics.ObservableUpDownCounter.create("n")
    end

    test "forwards unit and description opts" do
      assert %Otel.Metrics.Instrument{
               kind: :observable_updown_counter,
               name: "n",
               unit: "By",
               description: "Process heap size"
             } =
               Otel.Metrics.ObservableUpDownCounter.create("n",
                 unit: "By",
                 description: "Process heap size"
               )
    end
  end

  describe "create/5 — with inline callback (spec L446-L447 MUST)" do
    test "attaches callback at creation time" do
      callback = fn _args -> [%Otel.Metrics.Measurement{value: 1024, attributes: %{}}] end

      assert %Otel.Metrics.Instrument{kind: :observable_updown_counter, name: "n"} =
               Otel.Metrics.ObservableUpDownCounter.create("n", callback, nil, [])
    end

    test "forwards callback_args (spec L655-L658 SHOULD opaque state)" do
      callback = fn pid ->
        {:heap_size, n} = Process.info(pid, :heap_size)
        [%Otel.Metrics.Measurement{value: n, attributes: %{}}]
      end

      assert %Otel.Metrics.Instrument{kind: :observable_updown_counter, unit: "words"} =
               Otel.Metrics.ObservableUpDownCounter.create(
                 "heap_size",
                 callback,
                 self(),
                 unit: "words"
               )
    end
  end
end
