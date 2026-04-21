defmodule Otel.API.Trace.EventTest do
  use ExUnit.Case, async: true

  describe "new/1,2,3" do
    test "creates an event with defaults for attributes and timestamp" do
      before = System.system_time(:nanosecond)
      event = Otel.API.Trace.Event.new("my_event")
      after_time = System.system_time(:nanosecond)

      assert event.name == "my_event"
      assert event.attributes == %{}
      assert event.timestamp >= before
      assert event.timestamp <= after_time
    end

    test "creates an event with attributes and default timestamp" do
      before = System.system_time(:nanosecond)
      event = Otel.API.Trace.Event.new("my_event", %{"key" => "val"})
      after_time = System.system_time(:nanosecond)

      assert event.name == "my_event"
      assert event.attributes == %{"key" => "val"}
      assert event.timestamp >= before
      assert event.timestamp <= after_time
    end

    test "creates an event with explicit timestamp" do
      event = Otel.API.Trace.Event.new("my_event", %{"k" => "v"}, 1_234_567_890)

      assert event.name == "my_event"
      assert event.attributes == %{"k" => "v"}
      assert event.timestamp == 1_234_567_890
    end

    test "explicit zero timestamp is preserved verbatim" do
      event = Otel.API.Trace.Event.new("e", %{}, 0)

      assert event.timestamp == 0
    end
  end

  describe "struct defaults" do
    test "default struct has empty name, zero timestamp, empty attributes" do
      event = %Otel.API.Trace.Event{}

      assert event.name == ""
      assert event.timestamp == 0
      assert event.attributes == %{}
    end
  end
end
