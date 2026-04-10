defmodule Otel.API.Trace.SpanTest do
  use ExUnit.Case, async: true

  alias Otel.API.Trace.{Span, SpanContext}

  @valid_ctx SpanContext.new(
               0xFF000000000000000000000000000001,
               0xFF00000000000001,
               1
             )
  @invalid_ctx %SpanContext{}

  describe "get_context/1" do
    test "returns the same SpanContext" do
      assert Span.get_context(@valid_ctx) == @valid_ctx
    end

    test "returns invalid SpanContext as-is" do
      assert Span.get_context(@invalid_ctx) == @invalid_ctx
    end
  end

  describe "recording?/1" do
    test "returns false without SDK (always non-recording)" do
      assert Span.recording?(@valid_ctx) == false
    end

    test "returns false for invalid span" do
      assert Span.recording?(@invalid_ctx) == false
    end
  end

  describe "no-op operations on API level" do
    test "set_attribute with string key returns :ok" do
      assert Span.set_attribute(@valid_ctx, "key", "value") == :ok
    end

    test "set_attribute with atom key returns :ok" do
      assert Span.set_attribute(@valid_ctx, :key, "value") == :ok
    end

    test "set_attributes with map returns :ok" do
      assert Span.set_attributes(@valid_ctx, %{key: "value"}) == :ok
    end

    test "set_attributes with keyword list returns :ok" do
      assert Span.set_attributes(@valid_ctx, key: "value", other: 42) == :ok
    end

    test "add_event with string name returns :ok" do
      assert Span.add_event(@valid_ctx, "event_name") == :ok
    end

    test "add_event with atom name returns :ok" do
      assert Span.add_event(@valid_ctx, :event_name) == :ok
    end

    test "add_event with opts returns :ok" do
      assert Span.add_event(@valid_ctx, "event_name", attributes: %{key: "val"}, time: 1_000) ==
               :ok
    end

    test "add_link returns :ok" do
      other = SpanContext.new(0xAA, 0xBB)
      assert Span.add_link(@valid_ctx, other) == :ok
    end

    test "add_link with attributes returns :ok" do
      other = SpanContext.new(0xAA, 0xBB)
      assert Span.add_link(@valid_ctx, other, %{key: "val"}) == :ok
    end

    test "set_status :ok returns :ok" do
      assert Span.set_status(@valid_ctx, :ok) == :ok
    end

    test "set_status :error with description returns :ok" do
      assert Span.set_status(@valid_ctx, :error, "something failed") == :ok
    end

    test "set_status :error without description returns :ok" do
      assert Span.set_status(@valid_ctx, :error) == :ok
    end

    test "set_status :unset returns :ok" do
      assert Span.set_status(@valid_ctx, :unset) == :ok
    end

    test "update_name returns :ok" do
      assert Span.update_name(@valid_ctx, "new_name") == :ok
    end

    test "end_span returns :ok" do
      assert Span.end_span(@valid_ctx) == :ok
    end

    test "end_span with timestamp returns :ok" do
      assert Span.end_span(@valid_ctx, 1_000_000) == :ok
    end

    test "record_exception returns :ok" do
      assert Span.record_exception(@valid_ctx, %RuntimeError{message: "oops"}) == :ok
    end

    test "record_exception with stacktrace returns :ok" do
      assert Span.record_exception(
               @valid_ctx,
               %RuntimeError{message: "oops"},
               [{__MODULE__, :test, 0, []}]
             ) == :ok
    end

    test "record_exception with stacktrace and attributes returns :ok" do
      assert Span.record_exception(
               @valid_ctx,
               %RuntimeError{message: "oops"},
               [{__MODULE__, :test, 0, []}],
               %{extra: "info"}
             ) == :ok
    end
  end

  describe "operations on invalid span" do
    test "set_attribute on invalid span returns :ok" do
      assert Span.set_attribute(@invalid_ctx, "key", "value") == :ok
    end

    test "add_event on invalid span returns :ok" do
      assert Span.add_event(@invalid_ctx, "event") == :ok
    end

    test "set_status on invalid span returns :ok" do
      assert Span.set_status(@invalid_ctx, :error, "fail") == :ok
    end

    test "end_span on invalid span returns :ok" do
      assert Span.end_span(@invalid_ctx) == :ok
    end

    test "record_exception on invalid span returns :ok" do
      assert Span.record_exception(@invalid_ctx, %RuntimeError{message: "oops"}) == :ok
    end
  end
end
