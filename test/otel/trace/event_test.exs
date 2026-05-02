defmodule Otel.Trace.EventTest do
  use ExUnit.Case, async: true

  describe "new/3" do
    test "fills timestamp with current time when omitted" do
      before_time = System.system_time(:nanosecond)
      event = Otel.Trace.Event.new("my_event")
      after_time = System.system_time(:nanosecond)

      assert event.timestamp in before_time..after_time
    end

    test "preserves explicit timestamp verbatim (including zero)" do
      assert Otel.Trace.Event.new("e", %{}, 1_234_567_890).timestamp == 1_234_567_890
      assert Otel.Trace.Event.new("e", %{}, 0).timestamp == 0
    end

    test "forwards name and attributes to the struct" do
      event = Otel.Trace.Event.new("my_event", %{"key" => "val"})

      assert event.name == "my_event"
      assert event.attributes == %{"key" => "val"}
    end

    test "defaults attributes to an empty map" do
      assert Otel.Trace.Event.new("e").attributes == %{}
    end
  end

  describe "%Otel.Trace.Event{}" do
    test "default struct has empty name, zero timestamp, empty attributes" do
      assert %Otel.Trace.Event{} ==
               %Otel.Trace.Event{name: "", timestamp: 0, attributes: %{}}
    end
  end
end
