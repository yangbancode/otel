defmodule Otel.API.Trace.Span.NoopTest do
  use ExUnit.Case, async: true

  @valid_ctx Otel.API.Trace.SpanContext.new(
               0xFF000000000000000000000000000001,
               0xFF00000000000001,
               1
             )

  describe "recording?/1" do
    test "always returns false" do
      assert Otel.API.Trace.Span.Noop.recording?(@valid_ctx) == false
    end

    test "returns false for invalid SpanContext" do
      assert Otel.API.Trace.Span.Noop.recording?(%Otel.API.Trace.SpanContext{}) == false
    end
  end

  describe "set_attribute/3" do
    test "returns :ok" do
      assert Otel.API.Trace.Span.Noop.set_attribute(@valid_ctx, "key", "value") == :ok
    end

    test "accepts any primitive value type" do
      assert Otel.API.Trace.Span.Noop.set_attribute(@valid_ctx, "k", 42) == :ok
      assert Otel.API.Trace.Span.Noop.set_attribute(@valid_ctx, "k", true) == :ok
      assert Otel.API.Trace.Span.Noop.set_attribute(@valid_ctx, "k", [1, 2, 3]) == :ok
    end
  end

  describe "set_attributes/2" do
    test "returns :ok" do
      assert Otel.API.Trace.Span.Noop.set_attributes(@valid_ctx, %{"key" => "val"}) == :ok
    end

    test "accepts empty map" do
      assert Otel.API.Trace.Span.Noop.set_attributes(@valid_ctx, %{}) == :ok
    end
  end

  describe "add_event/2" do
    test "returns :ok" do
      event = Otel.API.Trace.Event.new("event_name")
      assert Otel.API.Trace.Span.Noop.add_event(@valid_ctx, event) == :ok
    end

    test "accepts event with attributes" do
      event = Otel.API.Trace.Event.new("event", %{"k" => "v"})
      assert Otel.API.Trace.Span.Noop.add_event(@valid_ctx, event) == :ok
    end
  end

  describe "add_link/2" do
    test "returns :ok" do
      other = Otel.API.Trace.SpanContext.new(0xAA, 0xBB)
      link = %Otel.API.Trace.Link{context: other}
      assert Otel.API.Trace.Span.Noop.add_link(@valid_ctx, link) == :ok
    end
  end

  describe "set_status/2" do
    test "returns :ok for :ok status" do
      assert Otel.API.Trace.Span.Noop.set_status(@valid_ctx, Otel.API.Trace.Status.new(:ok)) ==
               :ok
    end

    test "returns :ok for :error status with description" do
      status = Otel.API.Trace.Status.new(:error, "boom")
      assert Otel.API.Trace.Span.Noop.set_status(@valid_ctx, status) == :ok
    end
  end

  describe "update_name/2" do
    test "returns :ok" do
      assert Otel.API.Trace.Span.Noop.update_name(@valid_ctx, "new_name") == :ok
    end
  end

  describe "end_span/2" do
    test "returns :ok with timestamp" do
      assert Otel.API.Trace.Span.Noop.end_span(@valid_ctx, 1_000_000) == :ok
    end
  end

  describe "record_exception/4" do
    test "returns :ok" do
      assert Otel.API.Trace.Span.Noop.record_exception(
               @valid_ctx,
               %RuntimeError{message: "oops"},
               [],
               %{}
             ) == :ok
    end

    test "accepts additional attributes" do
      assert Otel.API.Trace.Span.Noop.record_exception(
               @valid_ctx,
               %RuntimeError{message: "oops"},
               [{__MODULE__, :test, 0, []}],
               %{"extra" => "info"}
             ) == :ok
    end
  end
end
