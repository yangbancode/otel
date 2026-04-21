defmodule Otel.API.Trace.TraceIdTest do
  use ExUnit.Case, async: true

  @max_trace_id 0xFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF

  describe "new/1" do
    test "wraps a non-negative integer" do
      assert Otel.API.Trace.TraceId.new(1) == 1
      assert Otel.API.Trace.TraceId.new(@max_trace_id) == @max_trace_id
    end

    test "raises FunctionClauseError on out-of-range input" do
      assert_raise FunctionClauseError, fn ->
        Otel.API.Trace.TraceId.new(@max_trace_id + 1)
      end

      assert_raise FunctionClauseError, fn ->
        Otel.API.Trace.TraceId.new(-1)
      end
    end
  end

  describe "invalid/0" do
    test "returns the all-zero sentinel" do
      assert Otel.API.Trace.TraceId.invalid() == 0
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

    test "roundtrips via from_bytes/1" do
      value = 0x0123456789ABCDEF_0123456789ABCDEF
      bytes = Otel.API.Trace.TraceId.to_bytes(value)
      assert Otel.API.Trace.TraceId.from_bytes(bytes) == value
    end
  end

  describe "from_hex/1" do
    test "parses 32-character lowercase hex" do
      assert Otel.API.Trace.TraceId.from_hex("00000000000000000000000000000000") == 0
      assert Otel.API.Trace.TraceId.from_hex("00000000000000000000000000000001") == 1

      assert Otel.API.Trace.TraceId.from_hex("ffffffffffffffffffffffffffffffff") ==
               @max_trace_id
    end
  end

  describe "from_bytes/1" do
    test "parses 16-byte binary" do
      assert Otel.API.Trace.TraceId.from_bytes(<<0::128>>) == 0
      assert Otel.API.Trace.TraceId.from_bytes(<<1::128>>) == 1
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
