defmodule Otel.API.Trace.SpanIdTest do
  use ExUnit.Case, async: true

  @max 0xFFFFFFFF_FFFFFFFF

  describe "new/1" do
    test "wraps an in-range integer as-is" do
      assert Otel.API.Trace.SpanId.new(0) == 0
      assert Otel.API.Trace.SpanId.new(1) == 1
      assert Otel.API.Trace.SpanId.new(@max) == @max
    end
  end

  describe "valid?/1" do
    # Spec trace/api.md L234-L235 + W3C parent-id L113-L117:
    # all-zero is the invalid sentinel; any other in-range value is valid.
    test "true for any non-zero in-range integer" do
      assert Otel.API.Trace.SpanId.valid?(1)
      assert Otel.API.Trace.SpanId.valid?(@max)
    end

    test "false for zero, out-of-range integers, and non-integers" do
      refute Otel.API.Trace.SpanId.valid?(0)
      refute Otel.API.Trace.SpanId.valid?(-1)
      refute Otel.API.Trace.SpanId.valid?(@max + 1)
      refute Otel.API.Trace.SpanId.valid?("0000000000000001")
      refute Otel.API.Trace.SpanId.valid?(nil)
    end
  end

  describe "to_hex/1" do
    # Spec trace/api.md L258-L262 + W3C parent-id `16HEXDIGLC`:
    # 16-character lowercase zero-padded hex.
    test "encodes as 16-character lowercase hex (zero-padded)" do
      assert Otel.API.Trace.SpanId.to_hex(0) == "0000000000000000"
      assert Otel.API.Trace.SpanId.to_hex(1) == "0000000000000001"
      assert Otel.API.Trace.SpanId.to_hex(0x123) == "0000000000000123"
      assert Otel.API.Trace.SpanId.to_hex(@max) == "ffffffffffffffff"
    end
  end

  describe "to_bytes/1" do
    # Spec trace/api.md L263-L264: 8-byte big-endian binary.
    test "encodes as 8-byte big-endian binary" do
      assert Otel.API.Trace.SpanId.to_bytes(0) == <<0, 0, 0, 0, 0, 0, 0, 0>>
      assert Otel.API.Trace.SpanId.to_bytes(1) == <<0, 0, 0, 0, 0, 0, 0, 1>>

      assert Otel.API.Trace.SpanId.to_bytes(0x0123456789ABCDEF) ==
               <<0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF>>
    end
  end
end
