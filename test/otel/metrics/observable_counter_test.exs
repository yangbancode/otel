defmodule Otel.Metrics.ObservableCounterTest do
  use ExUnit.Case, async: false

  setup do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)

    :ok
  end

  describe "create/3 — without callback" do
    test "with name only" do
      assert %Otel.Metrics.Instrument{kind: :observable_counter, name: "n"} =
               Otel.Metrics.ObservableCounter.create("n")
    end

    test "forwards unit and description opts" do
      assert %Otel.Metrics.Instrument{
               kind: :observable_counter,
               name: "n",
               unit: "s",
               description: "CPU time per thread"
             } =
               Otel.Metrics.ObservableCounter.create("n",
                 unit: "s",
                 description: "CPU time per thread"
               )
    end
  end

  describe "create/5 — with inline callback (spec L446-L447 MUST)" do
    test "attaches callback at creation time" do
      callback = fn _args -> [%Otel.Metrics.Measurement{value: 100, attributes: %{}}] end

      assert %Otel.Metrics.Instrument{kind: :observable_counter, name: "n"} =
               Otel.Metrics.ObservableCounter.create("n", callback, nil, [])
    end

    test "forwards callback_args (spec L655-L658 SHOULD opaque state)" do
      callback = fn pid ->
        {:reductions, n} = Process.info(pid, :reductions)
        [%Otel.Metrics.Measurement{value: n, attributes: %{}}]
      end

      assert %Otel.Metrics.Instrument{
               kind: :observable_counter,
               unit: "1",
               description: "Process reductions"
             } =
               Otel.Metrics.ObservableCounter.create(
                 "reductions",
                 callback,
                 self(),
                 unit: "1",
                 description: "Process reductions"
               )
    end
  end
end
