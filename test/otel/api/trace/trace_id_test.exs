defmodule Otel.API.Trace.TraceIdTest do
  use ExUnit.Case, async: true

  @max_trace_id 0xFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF

  describe "new/1" do
    test "wraps a 128-bit unsigned integer" do
      assert Otel.API.Trace.TraceId.new(0) == 0
      assert Otel.API.Trace.TraceId.new(1) == 1
      assert Otel.API.Trace.TraceId.new(@max_trace_id) == @max_trace_id
    end
  end

  describe "valid?/1" do
    test "returns false for zero" do
      refute Otel.API.Trace.TraceId.valid?(0)
    end

    test "returns true for any non-zero in-range value" do
      assert Otel.API.Trace.TraceId.valid?(1)
      assert Otel.API.Trace.TraceId.valid?(@max_trace_id)
    end

    test "returns false for out-of-range or non-integer term" do
      refute Otel.API.Trace.TraceId.valid?(-1)
      refute Otel.API.Trace.TraceId.valid?(@max_trace_id + 1)
      refute Otel.API.Trace.TraceId.valid?("string")
      refute Otel.API.Trace.TraceId.valid?(nil)
    end
  end

  describe "to_hex/1" do
    test "returns 32-character lowercase zero-padded hex" do
      assert Otel.API.Trace.TraceId.to_hex(0) == "00000000000000000000000000000000"
      assert Otel.API.Trace.TraceId.to_hex(1) == "00000000000000000000000000000001"

      assert Otel.API.Trace.TraceId.to_hex(@max_trace_id) ==
               "ffffffffffffffffffffffffffffffff"
    end

    test "length is always 32 characters" do
      for _ <- 1..20 do
        value = :rand.uniform(@max_trace_id)
        assert byte_size(Otel.API.Trace.TraceId.to_hex(value)) == 32
      end
    end
  end

  describe "to_bytes/1" do
    test "returns 16-byte big-endian binary" do
      assert Otel.API.Trace.TraceId.to_bytes(0) == <<0::128>>
      assert Otel.API.Trace.TraceId.to_bytes(1) == <<1::128>>
    end

    test "encodes integer big-endian" do
      value = 0x0123456789ABCDEF_0123456789ABCDEF
      assert Otel.API.Trace.TraceId.to_bytes(value) == <<value::unsigned-integer-size(128)>>
    end
  end

  describe "to_integer/1" do
    test "returns the underlying integer" do
      assert Otel.API.Trace.TraceId.to_integer(0) == 0
      assert Otel.API.Trace.TraceId.to_integer(42) == 42
      assert Otel.API.Trace.TraceId.to_integer(@max_trace_id) == @max_trace_id
    end
  end
end
