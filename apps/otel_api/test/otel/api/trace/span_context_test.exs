defmodule Otel.API.Trace.SpanContextTest do
  use ExUnit.Case, async: true

  @valid_trace_id 0xFF000000000000000000000000000001
  @valid_span_id 0xFF00000000000001
  @zero_trace_id 0
  @zero_span_id 0

  describe "new/2,3,4" do
    test "creates context with non-zero IDs" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id)
      assert ctx.trace_id == @valid_trace_id
      assert ctx.span_id == @valid_span_id
      assert ctx.trace_flags == 0
      assert ctx.tracestate == Otel.API.Trace.TraceState.new()
      assert ctx.is_remote == false
    end

    test "accepts trace_flags and tracestate" do
      ts = Otel.API.Trace.TraceState.new() |> Otel.API.Trace.TraceState.add("vendor", "value")
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 1, ts)
      assert ctx.trace_flags == 1
      assert ctx.tracestate == ts
    end
  end

  describe "valid?/1" do
    test "returns true for valid context" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id)
      assert Otel.API.Trace.SpanContext.valid?(ctx) == true
    end

    test "returns false when trace_id is zero" do
      ctx = Otel.API.Trace.SpanContext.new(@zero_trace_id, @valid_span_id)
      assert Otel.API.Trace.SpanContext.valid?(ctx) == false
    end

    test "returns false when span_id is zero" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @zero_span_id)
      assert Otel.API.Trace.SpanContext.valid?(ctx) == false
    end

    test "returns false when both are zero" do
      ctx = Otel.API.Trace.SpanContext.new(@zero_trace_id, @zero_span_id)
      assert Otel.API.Trace.SpanContext.valid?(ctx) == false
    end
  end

  describe "remote?/1" do
    test "returns false by default" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id)
      assert Otel.API.Trace.SpanContext.remote?(ctx) == false
    end

    test "returns true when is_remote is set" do
      ctx = %{Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id) | is_remote: true}
      assert Otel.API.Trace.SpanContext.remote?(ctx) == true
    end
  end

  describe "sampled?/1" do
    test "returns false when trace_flags lowest bit is 0" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 0)
      assert Otel.API.Trace.SpanContext.sampled?(ctx) == false
    end

    test "returns true when trace_flags lowest bit is 1" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 1)
      assert Otel.API.Trace.SpanContext.sampled?(ctx) == true
    end

    test "checks only lowest bit" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 0b10)
      assert Otel.API.Trace.SpanContext.sampled?(ctx) == false

      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 0b11)
      assert Otel.API.Trace.SpanContext.sampled?(ctx) == true
    end
  end

  describe "random?/1" do
    test "returns false when trace_flags bit 1 is 0" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 0)
      assert Otel.API.Trace.SpanContext.random?(ctx) == false
    end

    test "returns true when trace_flags bit 1 is 1" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 0b10)
      assert Otel.API.Trace.SpanContext.random?(ctx) == true
    end

    test "checks only bit 1, independent of Sampled bit" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 0b01)
      assert Otel.API.Trace.SpanContext.random?(ctx) == false

      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id, 0b11)
      assert Otel.API.Trace.SpanContext.random?(ctx) == true
    end
  end

  describe "trace_id_hex/1" do
    test "returns 32-char lowercase hex string" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id)
      hex = Otel.API.Trace.SpanContext.trace_id_hex(ctx)
      assert String.length(hex) == 32
      assert hex == String.downcase(hex)
    end

    test "zero trace_id returns 32 zeros" do
      ctx = Otel.API.Trace.SpanContext.new(@zero_trace_id, @valid_span_id)
      assert Otel.API.Trace.SpanContext.trace_id_hex(ctx) == "00000000000000000000000000000000"
    end

    test "pads short hex values with leading zeros" do
      ctx = Otel.API.Trace.SpanContext.new(1, @valid_span_id)
      assert Otel.API.Trace.SpanContext.trace_id_hex(ctx) == "00000000000000000000000000000001"
    end
  end

  describe "span_id_hex/1" do
    test "returns 16-char lowercase hex string" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id)
      hex = Otel.API.Trace.SpanContext.span_id_hex(ctx)
      assert String.length(hex) == 16
      assert hex == String.downcase(hex)
    end

    test "zero span_id returns 16 zeros" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @zero_span_id)
      assert Otel.API.Trace.SpanContext.span_id_hex(ctx) == "0000000000000000"
    end

    test "pads short hex values with leading zeros" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, 1)
      assert Otel.API.Trace.SpanContext.span_id_hex(ctx) == "0000000000000001"
    end
  end

  describe "trace_id_bytes/1" do
    test "returns 16-byte binary" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id)
      bytes = Otel.API.Trace.SpanContext.trace_id_bytes(ctx)
      assert byte_size(bytes) == 16
    end

    test "zero trace_id returns 16 zero bytes" do
      ctx = Otel.API.Trace.SpanContext.new(@zero_trace_id, @valid_span_id)
      assert Otel.API.Trace.SpanContext.trace_id_bytes(ctx) == <<0::128>>
    end

    test "roundtrips with integer" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id)
      <<roundtrip::unsigned-integer-size(128)>> = Otel.API.Trace.SpanContext.trace_id_bytes(ctx)
      assert roundtrip == @valid_trace_id
    end
  end

  describe "span_id_bytes/1" do
    test "returns 8-byte binary" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id)
      bytes = Otel.API.Trace.SpanContext.span_id_bytes(ctx)
      assert byte_size(bytes) == 8
    end

    test "zero span_id returns 8 zero bytes" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @zero_span_id)
      assert Otel.API.Trace.SpanContext.span_id_bytes(ctx) == <<0::64>>
    end

    test "roundtrips with integer" do
      ctx = Otel.API.Trace.SpanContext.new(@valid_trace_id, @valid_span_id)
      <<roundtrip::unsigned-integer-size(64)>> = Otel.API.Trace.SpanContext.span_id_bytes(ctx)
      assert roundtrip == @valid_span_id
    end
  end

  describe "struct defaults" do
    test "default struct has all zeros and is invalid" do
      ctx = %Otel.API.Trace.SpanContext{}
      assert ctx.trace_id == 0
      assert ctx.span_id == 0
      assert ctx.trace_flags == 0
      assert ctx.tracestate == Otel.API.Trace.TraceState.new()
      assert ctx.is_remote == false
      assert Otel.API.Trace.SpanContext.valid?(ctx) == false
    end
  end
end
