defmodule Otel.API.Trace.SpanIdTest do
  use ExUnit.Case, async: true

  require Otel.API.Trace.SpanId

  @max_span_id 0xFFFFFFFF_FFFFFFFF

  describe "new/1" do
    test "wraps a non-negative integer" do
      assert Otel.API.Trace.SpanId.new(1) == 1
      assert Otel.API.Trace.SpanId.new(@max_span_id) == @max_span_id
    end

    test "raises FunctionClauseError on out-of-range input" do
      assert_raise FunctionClauseError, fn ->
        Otel.API.Trace.SpanId.new(@max_span_id + 1)
      end

      assert_raise FunctionClauseError, fn ->
        Otel.API.Trace.SpanId.new(-1)
      end
    end
  end

  describe "invalid/0" do
    test "returns the all-zero sentinel" do
      assert Otel.API.Trace.SpanId.invalid() == 0
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

    test "roundtrips via from_bytes/1" do
      value = 0x0123456789ABCDEF
      bytes = Otel.API.Trace.SpanId.to_bytes(value)
      assert {:ok, ^value} = Otel.API.Trace.SpanId.from_bytes(bytes)
    end
  end

  describe "from_hex/1" do
    test "parses 16-character lowercase hex" do
      assert {:ok, 0} = Otel.API.Trace.SpanId.from_hex("0000000000000000")
      assert {:ok, 1} = Otel.API.Trace.SpanId.from_hex("0000000000000001")
      assert {:ok, @max_span_id} = Otel.API.Trace.SpanId.from_hex("ffffffffffffffff")
    end

    test "returns :error on wrong length" do
      assert :error = Otel.API.Trace.SpanId.from_hex("")
      assert :error = Otel.API.Trace.SpanId.from_hex("1")
      assert :error = Otel.API.Trace.SpanId.from_hex(String.duplicate("0", 17))
    end

    test "returns :error on non-hex characters" do
      assert :error = Otel.API.Trace.SpanId.from_hex(String.duplicate("z", 16))
    end

    test "returns :error on non-binary input" do
      assert :error = Otel.API.Trace.SpanId.from_hex(42)
      assert :error = Otel.API.Trace.SpanId.from_hex(nil)
    end
  end

  describe "from_bytes/1" do
    test "parses 8-byte binary" do
      assert {:ok, 0} = Otel.API.Trace.SpanId.from_bytes(<<0::64>>)
      assert {:ok, 1} = Otel.API.Trace.SpanId.from_bytes(<<1::64>>)
    end

    test "returns :error on wrong byte size" do
      assert :error = Otel.API.Trace.SpanId.from_bytes(<<>>)
      assert :error = Otel.API.Trace.SpanId.from_bytes(<<0::32>>)
      assert :error = Otel.API.Trace.SpanId.from_bytes(<<0::128>>)
    end
  end
end
