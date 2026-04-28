defmodule Otel.API.Metrics.Meter.NoopTest do
  use ExUnit.Case, async: true

  # Spec metrics/noop.md §Meter L33-L35: a Noop component MUST NOT
  # validate any argument and MUST NOT return any non-empty error.
  # All creation calls return a properly-typed Instrument; all
  # recording calls return :ok; enabled? is always false; callbacks
  # are never invoked.

  @meter {Otel.API.Metrics.Meter.Noop, []}

  defp raising_callback, do: fn _args -> raise "callback MUST NOT be invoked by Noop" end

  describe "create_* — every kind returns a typed Instrument" do
    test "synchronous instruments" do
      assert %Otel.API.Metrics.Instrument{kind: :counter, name: "c"} =
               Otel.API.Metrics.Meter.Noop.create_counter(@meter, "c", [])

      assert %Otel.API.Metrics.Instrument{kind: :updown_counter, name: "udc"} =
               Otel.API.Metrics.Meter.Noop.create_updown_counter(@meter, "udc", [])

      assert %Otel.API.Metrics.Instrument{kind: :histogram, name: "h"} =
               Otel.API.Metrics.Meter.Noop.create_histogram(@meter, "h", [])

      assert %Otel.API.Metrics.Instrument{kind: :gauge, name: "g"} =
               Otel.API.Metrics.Meter.Noop.create_gauge(@meter, "g", [])
    end

    test "asynchronous instruments without callback" do
      assert %Otel.API.Metrics.Instrument{kind: :observable_counter, name: "oc"} =
               Otel.API.Metrics.Meter.Noop.create_observable_counter(@meter, "oc", [])

      assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter, name: "oudc"} =
               Otel.API.Metrics.Meter.Noop.create_observable_updown_counter(@meter, "oudc", [])

      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge, name: "og"} =
               Otel.API.Metrics.Meter.Noop.create_observable_gauge(@meter, "og", [])
    end

    # Spec noop.md L149/L164/L179 — Noop MUST accept callbacks but
    # MUST NOT retain or invoke them. Raising callback proves
    # non-invocation.
    test "asynchronous instruments with callback are accepted, callback never invoked" do
      assert %Otel.API.Metrics.Instrument{kind: :observable_counter} =
               Otel.API.Metrics.Meter.Noop.create_observable_counter(
                 @meter,
                 "oc",
                 raising_callback(),
                 :state,
                 []
               )

      assert %Otel.API.Metrics.Instrument{kind: :observable_updown_counter} =
               Otel.API.Metrics.Meter.Noop.create_observable_updown_counter(
                 @meter,
                 "oudc",
                 raising_callback(),
                 :state,
                 []
               )

      assert %Otel.API.Metrics.Instrument{kind: :observable_gauge} =
               Otel.API.Metrics.Meter.Noop.create_observable_gauge(
                 @meter,
                 "og",
                 raising_callback(),
                 :state,
                 []
               )
    end

    test "forwards unit, description, advisory opts (spec L81 MUST accept)" do
      assert %Otel.API.Metrics.Instrument{unit: "ms", description: "d", advisory: [hint: 1]} =
               Otel.API.Metrics.Meter.Noop.create_counter(@meter, "c",
                 unit: "ms",
                 description: "d",
                 advisory: [hint: 1]
               )
    end

    # Optional opts coerce nil → default — required for callers that
    # pass through caller-supplied opts that may carry nils.
    test "nil unit / description / advisory each coerce to their defaults" do
      assert %Otel.API.Metrics.Instrument{unit: "", description: "", advisory: []} =
               Otel.API.Metrics.Meter.Noop.create_counter(@meter, "c",
                 unit: nil,
                 description: nil,
                 advisory: nil
               )
    end
  end

  test "record/3 returns :ok regardless of value sign or attributes" do
    counter = %Otel.API.Metrics.Instrument{kind: :counter, name: "c"}
    histogram = %Otel.API.Metrics.Instrument{kind: :histogram, name: "h"}

    assert :ok = Otel.API.Metrics.Meter.Noop.record(counter, 42, %{})
    assert :ok = Otel.API.Metrics.Meter.Noop.record(histogram, -1.5, %{"any" => "value"})
  end

  test "register_callback/5 returns the {Noop, :noop} sentinel handle" do
    assert {Otel.API.Metrics.Meter.Noop, :noop} =
             Otel.API.Metrics.Meter.Noop.register_callback(@meter, [], raising_callback(), :s, [])
  end

  test "unregister_callback/1 accepts any handle shape" do
    assert :ok = Otel.API.Metrics.Meter.Noop.unregister_callback(:noop)
    assert :ok = Otel.API.Metrics.Meter.Noop.unregister_callback({:some, :other, :shape})
  end

  # Spec api.md L475-L495 — a Noop meter is by definition not
  # enabled; opts cannot change the answer.
  test "enabled?/2 always false, regardless of opts" do
    inst = %Otel.API.Metrics.Instrument{kind: :counter, name: "c"}
    refute Otel.API.Metrics.Meter.Noop.enabled?(inst, [])
    refute Otel.API.Metrics.Meter.Noop.enabled?(inst, some: :hint)
  end
end
