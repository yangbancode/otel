defmodule Otel.API.Metrics.Meter.NoopTest do
  use ExUnit.Case, async: true

  @meter {Otel.API.Metrics.Meter.Noop, []}

  describe "sync instrument creation (noop.md §Meter L95-L135)" do
    test "create_counter returns Instrument with :counter kind" do
      assert %Otel.API.Metrics.Instrument{kind: :counter, name: "c"} =
               Otel.API.Metrics.Meter.Noop.create_counter(@meter, "c", [])
    end

    test "create_updown_counter returns Instrument with :updown_counter kind" do
      assert %Otel.API.Metrics.Instrument{kind: :updown_counter, name: "udc"} =
               Otel.API.Metrics.Meter.Noop.create_updown_counter(@meter, "udc", [])
    end

    test "create_histogram returns Instrument with :histogram kind" do
      assert %Otel.API.Metrics.Instrument{kind: :histogram, name: "h"} =
               Otel.API.Metrics.Meter.Noop.create_histogram(@meter, "h", [])
    end

    test "create_gauge returns Instrument with :gauge kind" do
      assert %Otel.API.Metrics.Instrument{kind: :gauge, name: "g"} =
               Otel.API.Metrics.Meter.Noop.create_gauge(@meter, "g", [])
    end

    test "creation accepts opts without validation (noop.md L81)" do
      assert %Otel.API.Metrics.Instrument{unit: "ms", description: "d", advisory: [hint: 1]} =
               Otel.API.Metrics.Meter.Noop.create_counter(@meter, "c",
                 unit: "ms",
                 description: "d",
                 advisory: [hint: 1]
               )
    end
  end

  describe "async instrument creation without callback (noop.md §Async L137-L179)" do
    test "create_observable_counter/3 returns Instrument with :observable_counter kind" do
      assert %Otel.API.Metrics.Instrument{kind: :observable_counter, name: "oc"} =
               Otel.API.Metrics.Meter.Noop.create_observable_counter(@meter, "oc", [])
    end

    test "create_observable_updown_counter/3 returns :observable_updown_counter" do
      assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter} =
               Otel.API.Metrics.Meter.Noop.create_observable_updown_counter(@meter, "oudc", [])
    end

    test "create_observable_gauge/3 returns :observable_gauge" do
      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge} =
               Otel.API.Metrics.Meter.Noop.create_observable_gauge(@meter, "og", [])
    end
  end

  describe "async instrument creation with callback (noop.md L149/L164/L179 no-retention)" do
    # The callback raises if invoked. Noop MUST NOT retain or invoke it,
    # so creation must complete without touching the callback.
    test "create_observable_counter/5 accepts and discards callback" do
      callback = fn _args -> raise "callback MUST NOT be invoked by Noop" end

      assert %Otel.API.Metrics.Instrument{kind: :observable_counter} =
               Otel.API.Metrics.Meter.Noop.create_observable_counter(
                 @meter,
                 "oc",
                 callback,
                 :state,
                 []
               )
    end

    test "create_observable_updown_counter/5 accepts and discards callback" do
      callback = fn _args -> raise "callback MUST NOT be invoked by Noop" end

      assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter} =
               Otel.API.Metrics.Meter.Noop.create_observable_updown_counter(
                 @meter,
                 "oudc",
                 callback,
                 :state,
                 []
               )
    end

    test "create_observable_gauge/5 accepts and discards callback" do
      callback = fn _args -> raise "callback MUST NOT be invoked by Noop" end

      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge} =
               Otel.API.Metrics.Meter.Noop.create_observable_gauge(
                 @meter,
                 "og",
                 callback,
                 :state,
                 []
               )
    end
  end

  describe "record/3 (noop.md §Counter Add / §Histogram Record L196-L227)" do
    test "returns :ok without validation" do
      instrument = %Otel.API.Metrics.Instrument{kind: :counter, name: "c"}
      assert :ok == Otel.API.Metrics.Meter.Noop.record(instrument, 42, %{})
    end

    test "accepts negative value and arbitrary attributes without validation" do
      instrument = %Otel.API.Metrics.Instrument{kind: :histogram, name: "h"}
      assert :ok == Otel.API.Metrics.Meter.Noop.record(instrument, -1.5, %{"any" => "value"})
    end
  end

  describe "register_callback/5 (asynchronous-instruments-and-callbacks.md)" do
    test "returns {Noop, :noop} registration handle" do
      callback = fn _args -> raise "callback MUST NOT be invoked by Noop" end

      assert {Otel.API.Metrics.Meter.Noop, :noop} ==
               Otel.API.Metrics.Meter.Noop.register_callback(@meter, [], callback, :state, [])
    end
  end

  describe "unregister_callback/1 (api.md L419-L420)" do
    test "accepts any state and returns :ok" do
      assert :ok == Otel.API.Metrics.Meter.Noop.unregister_callback(:noop)
      assert :ok == Otel.API.Metrics.Meter.Noop.unregister_callback({:some, :other, :shape})
    end
  end

  describe "enabled?/2 (api.md L475-L495)" do
    test "always returns false" do
      instrument = %Otel.API.Metrics.Instrument{kind: :counter, name: "c"}
      assert false == Otel.API.Metrics.Meter.Noop.enabled?(instrument, [])
    end

    test "returns false regardless of opts" do
      instrument = %Otel.API.Metrics.Instrument{kind: :histogram, name: "h"}
      assert false == Otel.API.Metrics.Meter.Noop.enabled?(instrument, some: :hint)
    end
  end

  describe "build/4 opts tolerance (noop.md L81 MUST accept)" do
    # name is required (String.t()); coercion is only for
    # optional opts per happy-path policy.
    test "nil unit coerces to empty string" do
      assert %Otel.API.Metrics.Instrument{unit: ""} =
               Otel.API.Metrics.Meter.Noop.create_counter(@meter, "c", unit: nil)
    end

    test "nil description coerces to empty string" do
      assert %Otel.API.Metrics.Instrument{description: ""} =
               Otel.API.Metrics.Meter.Noop.create_counter(@meter, "c", description: nil)
    end

    test "nil advisory coerces to empty list" do
      assert %Otel.API.Metrics.Instrument{advisory: []} =
               Otel.API.Metrics.Meter.Noop.create_counter(@meter, "c", advisory: nil)
    end
  end
end
