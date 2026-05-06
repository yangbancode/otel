defmodule Otel.Trace.EventTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "fills timestamp with current time when omitted" do
      before_time = System.system_time(:nanosecond)
      event = Otel.Trace.Event.new(%{name: "my_event"})
      after_time = System.system_time(:nanosecond)

      assert event.timestamp in before_time..after_time
    end

    test "preserves explicit timestamp verbatim (including zero)" do
      assert Otel.Trace.Event.new(%{name: "e", timestamp: 1_234_567_890}).timestamp ==
               1_234_567_890

      assert Otel.Trace.Event.new(%{name: "e", timestamp: 0}).timestamp == 0
    end

    test "forwards name and attributes to the struct" do
      event = Otel.Trace.Event.new(%{name: "my_event", attributes: %{"key" => "val"}})

      assert event.name == "my_event"
      assert event.attributes == %{"key" => "val"}
    end

    test "defaults attributes to an empty map" do
      assert Otel.Trace.Event.new(%{name: "e"}).attributes == %{}
    end

    test "new/0 yields a struct with proto3 zero-value defaults plus runtime timestamp" do
      event = Otel.Trace.Event.new()
      assert event.name == ""
      assert event.attributes == %{}
      assert event.dropped_attributes_count == 0
      assert is_integer(event.timestamp) and event.timestamp > 0
    end
  end
end
