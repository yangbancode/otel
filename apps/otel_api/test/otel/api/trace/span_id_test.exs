defmodule Otel.API.Trace.SpanIdTest do
  use ExUnit.Case, async: true

  require Otel.API.Trace.SpanId

  @max_span_id 0xFFFFFFFF_FFFFFFFF

  describe "new/1" do
    test "wraps a 64-bit unsigned integer" do
      assert Otel.API.Trace.SpanId.new(0) == 0
      assert Otel.API.Trace.SpanId.new(1) == 1
      assert Otel.API.Trace.SpanId.new(@max_span_id) == @max_span_id
    end
  end

  describe "valid?/1" do
    test "returns false for zero" do
      refute Otel.API.Trace.SpanId.valid?(0)
    end

    test "returns true for any non-zero in-range value" do
      assert Otel.API.Trace.SpanId.valid?(1)
      assert Otel.API.Trace.SpanId.valid?(@max_span_id)
    end

    test "returns false for out-of-range or non-integer term" do
      refute Otel.API.Trace.SpanId.valid?(-1)
      refute Otel.API.Trace.SpanId.valid?(@max_span_id + 1)
      refute Otel.API.Trace.SpanId.valid?("string")
      refute Otel.API.Trace.SpanId.valid?(nil)
    end
  end

  describe "is_invalid/1 guard" do
    test "matches zero in a guard" do
      result =
        case 0 do
          span_id when Otel.API.Trace.SpanId.is_invalid(span_id) -> :invalid
          _ -> :valid
        end

      assert result == :invalid
    end

    test "does not match non-zero in a guard" do
      result =
        case 42 do
          span_id when Otel.API.Trace.SpanId.is_invalid(span_id) -> :invalid
          _ -> :valid
        end

      assert result == :valid
    end
  end

  describe "to_hex/1" do
    test "returns 16-character lowercase zero-padded hex" do
      assert Otel.API.Trace.SpanId.to_hex(0) == "0000000000000000"
      assert Otel.API.Trace.SpanId.to_hex(1) == "0000000000000001"
      assert Otel.API.Trace.SpanId.to_hex(@max_span_id) == "ffffffffffffffff"
    end

    test "length is always 16 characters" do
      for _ <- 1..20 do
        value = :rand.uniform(@max_span_id)
        assert byte_size(Otel.API.Trace.SpanId.to_hex(value)) == 16
      end
    end
  end

  describe "to_bytes/1" do
    test "returns 8-byte big-endian binary" do
      assert Otel.API.Trace.SpanId.to_bytes(0) == <<0::64>>
      assert Otel.API.Trace.SpanId.to_bytes(1) == <<1::64>>
    end

    test "encodes integer big-endian" do
      value = 0x0123456789ABCDEF
      assert Otel.API.Trace.SpanId.to_bytes(value) == <<value::unsigned-integer-size(64)>>
    end
  end
end
