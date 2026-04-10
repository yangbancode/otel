defmodule Otel.API.Trace.SpanContextTest do
  use ExUnit.Case, async: true

  alias Otel.API.Trace.SpanContext

  @valid_trace_id 0xFF000000000000000000000000000001
  @valid_span_id 0xFF00000000000001
  @zero_trace_id 0
  @zero_span_id 0

  describe "new/2,3,4" do
    test "creates context with non-zero IDs" do
      ctx = SpanContext.new(@valid_trace_id, @valid_span_id)
      assert ctx.trace_id == @valid_trace_id
      assert ctx.span_id == @valid_span_id
      assert ctx.trace_flags == 0
      assert ctx.tracestate == []
      assert ctx.is_remote == false
    end

    test "accepts trace_flags and tracestate" do
      ctx = SpanContext.new(@valid_trace_id, @valid_span_id, 1, [{"vendor", "value"}])
      assert ctx.trace_flags == 1
      assert ctx.tracestate == [{"vendor", "value"}]
    end
  end

  describe "valid?/1" do
    test "returns true for valid context" do
      ctx = SpanContext.new(@valid_trace_id, @valid_span_id)
      assert SpanContext.valid?(ctx) == true
    end

    test "returns false when trace_id is zero" do
      ctx = SpanContext.new(@zero_trace_id, @valid_span_id)
      assert SpanContext.valid?(ctx) == false
    end

    test "returns false when span_id is zero" do
      ctx = SpanContext.new(@valid_trace_id, @zero_span_id)
      assert SpanContext.valid?(ctx) == false
    end

    test "returns false when both are zero" do
      ctx = SpanContext.new(@zero_trace_id, @zero_span_id)
      assert SpanContext.valid?(ctx) == false
    end
  end

  describe "remote?/1" do
    test "returns false by default" do
      ctx = SpanContext.new(@valid_trace_id, @valid_span_id)
      assert SpanContext.remote?(ctx) == false
    end

    test "returns true when is_remote is set" do
      ctx = %{SpanContext.new(@valid_trace_id, @valid_span_id) | is_remote: true}
      assert SpanContext.remote?(ctx) == true
    end
  end

  describe "sampled?/1" do
    test "returns false when trace_flags lowest bit is 0" do
      ctx = SpanContext.new(@valid_trace_id, @valid_span_id, 0)
      assert SpanContext.sampled?(ctx) == false
    end

    test "returns true when trace_flags lowest bit is 1" do
      ctx = SpanContext.new(@valid_trace_id, @valid_span_id, 1)
      assert SpanContext.sampled?(ctx) == true
    end

    test "checks only lowest bit" do
      ctx = SpanContext.new(@valid_trace_id, @valid_span_id, 0b10)
      assert SpanContext.sampled?(ctx) == false

      ctx = SpanContext.new(@valid_trace_id, @valid_span_id, 0b11)
      assert SpanContext.sampled?(ctx) == true
    end
  end

  describe "trace_id_hex/1" do
    test "returns 32-char lowercase hex string" do
      ctx = SpanContext.new(@valid_trace_id, @valid_span_id)
      hex = SpanContext.trace_id_hex(ctx)
      assert String.length(hex) == 32
      assert hex == String.downcase(hex)
    end

    test "zero trace_id returns 32 zeros" do
      ctx = SpanContext.new(@zero_trace_id, @valid_span_id)
      assert SpanContext.trace_id_hex(ctx) == "00000000000000000000000000000000"
    end

    test "pads short hex values with leading zeros" do
      ctx = SpanContext.new(1, @valid_span_id)
      assert SpanContext.trace_id_hex(ctx) == "00000000000000000000000000000001"
    end
  end

  describe "span_id_hex/1" do
    test "returns 16-char lowercase hex string" do
      ctx = SpanContext.new(@valid_trace_id, @valid_span_id)
      hex = SpanContext.span_id_hex(ctx)
      assert String.length(hex) == 16
      assert hex == String.downcase(hex)
    end

    test "zero span_id returns 16 zeros" do
      ctx = SpanContext.new(@valid_trace_id, @zero_span_id)
      assert SpanContext.span_id_hex(ctx) == "0000000000000000"
    end

    test "pads short hex values with leading zeros" do
      ctx = SpanContext.new(@valid_trace_id, 1)
      assert SpanContext.span_id_hex(ctx) == "0000000000000001"
    end
  end

  describe "struct defaults" do
    test "default struct has all zeros and is invalid" do
      ctx = %SpanContext{}
      assert ctx.trace_id == 0
      assert ctx.span_id == 0
      assert ctx.trace_flags == 0
      assert ctx.tracestate == []
      assert ctx.is_remote == false
      assert SpanContext.valid?(ctx) == false
    end
  end
end
