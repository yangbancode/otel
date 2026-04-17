# credo:disable-for-this-file Credo.Check.Refactor.Apply
defmodule Otel.API.Trace.SpanIdTest do
  use ExUnit.Case, async: true

  @valid_bytes <<0xFF, 0, 0, 0, 0, 0, 0, 1>>
  @valid_hex "ff00000000000001"

  describe "new/1" do
    test "wraps an 8-byte binary" do
      assert Otel.API.Trace.SpanId.new(@valid_bytes) ==
               %Otel.API.Trace.SpanId{bytes: @valid_bytes}
    end

    test "accepts the all-zero 8-byte binary" do
      assert Otel.API.Trace.SpanId.new(<<0::64>>) ==
               %Otel.API.Trace.SpanId{bytes: <<0::64>>}
    end

    test "rejects shorter binary" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Trace.SpanId, :new, [<<0::56>>])
      end
    end

    test "rejects longer binary" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Trace.SpanId, :new, [<<0::72>>])
      end
    end
  end

  describe "from_hex/1" do
    test "parses a 16-char lowercase hex string" do
      sid = Otel.API.Trace.SpanId.from_hex(@valid_hex)
      assert sid.bytes == @valid_bytes
    end

    test "parses mixed-case hex" do
      upper = String.upcase(@valid_hex)
      assert Otel.API.Trace.SpanId.from_hex(upper).bytes == @valid_bytes
    end

    test "rejects non-16-char hex" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Trace.SpanId, :from_hex, ["ff"])
      end
    end
  end

  describe "to_bytes/1" do
    test "returns the 8-byte binary" do
      sid = Otel.API.Trace.SpanId.new(@valid_bytes)
      assert Otel.API.Trace.SpanId.to_bytes(sid) == @valid_bytes
    end
  end

  describe "to_hex/1" do
    test "returns 16-char lowercase hex" do
      sid = Otel.API.Trace.SpanId.new(@valid_bytes)
      hex = Otel.API.Trace.SpanId.to_hex(sid)
      assert byte_size(hex) == 16
      assert hex == @valid_hex
      assert hex == String.downcase(hex)
    end

    test "pads leading zeros" do
      sid = Otel.API.Trace.SpanId.new(<<0::56, 1::8>>)
      assert Otel.API.Trace.SpanId.to_hex(sid) == "0000000000000001"
    end
  end

  describe "round-trip" do
    test "bytes → hex → bytes" do
      sid = Otel.API.Trace.SpanId.new(@valid_bytes)
      hex = Otel.API.Trace.SpanId.to_hex(sid)
      assert Otel.API.Trace.SpanId.from_hex(hex).bytes == @valid_bytes
    end
  end

  describe "invalid/0 and valid?/1" do
    test "invalid/0 returns all-zero bytes" do
      assert Otel.API.Trace.SpanId.invalid() ==
               %Otel.API.Trace.SpanId{bytes: <<0::64>>}
    end

    test "valid?/1 is false for invalid" do
      refute Otel.API.Trace.SpanId.valid?(Otel.API.Trace.SpanId.invalid())
    end

    test "valid?/1 is true for any non-zero SpanId" do
      assert Otel.API.Trace.SpanId.valid?(Otel.API.Trace.SpanId.new(@valid_bytes))
    end

    test "valid?/1 is true when only the last byte is set" do
      assert Otel.API.Trace.SpanId.valid?(Otel.API.Trace.SpanId.new(<<0::56, 1::8>>))
    end
  end
end
