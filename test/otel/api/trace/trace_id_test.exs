defmodule Otel.API.Trace.TraceIdTest do
  use ExUnit.Case, async: true

  @max 0xFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF

  describe "new/1" do
    test "wraps an in-range integer as-is" do
      assert Otel.API.Trace.TraceId.new(0) == 0
      assert Otel.API.Trace.TraceId.new(1) == 1
      assert Otel.API.Trace.TraceId.new(@max) == @max
    end
  end

  describe "valid?/1" do
    # Spec trace/api.md L231-L232 + W3C trace-id L103:
    # all-zero is the invalid sentinel; any other in-range value is valid.
    test "true for any non-zero in-range integer" do
      assert Otel.API.Trace.TraceId.valid?(1)
      assert Otel.API.Trace.TraceId.valid?(@max)
    end

    test "false for zero, out-of-range integers, and non-integers" do
      refute Otel.API.Trace.TraceId.valid?(0)
      refute Otel.API.Trace.TraceId.valid?(-1)
      refute Otel.API.Trace.TraceId.valid?(@max + 1)
      refute Otel.API.Trace.TraceId.valid?("00000000000000000000000000000001")
      refute Otel.API.Trace.TraceId.valid?(nil)
    end
  end

  describe "to_hex/1" do
    # Spec trace/api.md L258-L262 + W3C trace-id `32HEXDIGLC`:
    # 32-character lowercase zero-padded hex.
    test "encodes as 32-character lowercase hex (zero-padded)" do
      assert Otel.API.Trace.TraceId.to_hex(0) == "00000000000000000000000000000000"
      assert Otel.API.Trace.TraceId.to_hex(1) == "00000000000000000000000000000001"
      assert Otel.API.Trace.TraceId.to_hex(0x123) == "00000000000000000000000000000123"
      assert Otel.API.Trace.TraceId.to_hex(@max) == "ffffffffffffffffffffffffffffffff"
    end
  end

  describe "to_bytes/1" do
    # Spec trace/api.md L263-L264: 16-byte big-endian binary.
    test "encodes as 16-byte big-endian binary" do
      assert Otel.API.Trace.TraceId.to_bytes(0) == <<0::128>>
      assert Otel.API.Trace.TraceId.to_bytes(1) == <<0::120, 1>>

      assert Otel.API.Trace.TraceId.to_bytes(0x0123456789ABCDEF_FEDCBA9876543210) ==
               <<0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0xFE, 0xDC, 0xBA, 0x98, 0x76,
                 0x54, 0x32, 0x10>>
    end
  end

  describe "to_integer/1" do
    test "returns the underlying integer" do
      assert Otel.API.Trace.TraceId.to_integer(0) == 0
      assert Otel.API.Trace.TraceId.to_integer(42) == 42
      assert Otel.API.Trace.TraceId.to_integer(@max) == @max
    end
  end
end
