# credo:disable-for-this-file Credo.Check.Refactor.Apply
defmodule Otel.API.Trace.TraceIdTest do
  use ExUnit.Case, async: true

  @valid_bytes <<0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
  @valid_hex "ff000000000000000000000000000001"

  describe "new/1" do
    test "wraps a 16-byte binary" do
      assert Otel.API.Trace.TraceId.new(@valid_bytes) ==
               %Otel.API.Trace.TraceId{bytes: @valid_bytes}
    end

    test "accepts the all-zero 16-byte binary" do
      assert Otel.API.Trace.TraceId.new(<<0::128>>) ==
               %Otel.API.Trace.TraceId{bytes: <<0::128>>}
    end

    test "rejects shorter binary" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Trace.TraceId, :new, [<<0::120>>])
      end
    end

    test "rejects longer binary" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Trace.TraceId, :new, [<<0::136>>])
      end
    end
  end

  describe "from_hex/1" do
    test "parses a 32-char lowercase hex string" do
      tid = Otel.API.Trace.TraceId.from_hex(@valid_hex)
      assert tid.bytes == @valid_bytes
    end

    test "parses mixed-case hex" do
      upper = String.upcase(@valid_hex)
      assert Otel.API.Trace.TraceId.from_hex(upper).bytes == @valid_bytes
    end

    test "rejects non-32-char hex" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Trace.TraceId, :from_hex, ["ff"])
      end
    end
  end

  describe "to_bytes/1" do
    test "returns the 16-byte binary" do
      tid = Otel.API.Trace.TraceId.new(@valid_bytes)
      assert Otel.API.Trace.TraceId.to_bytes(tid) == @valid_bytes
    end
  end

  describe "to_hex/1" do
    test "returns 32-char lowercase hex" do
      tid = Otel.API.Trace.TraceId.new(@valid_bytes)
      hex = Otel.API.Trace.TraceId.to_hex(tid)
      assert byte_size(hex) == 32
      assert hex == @valid_hex
      assert hex == String.downcase(hex)
    end

    test "pads leading zeros" do
      tid = Otel.API.Trace.TraceId.new(<<0::120, 1::8>>)
      assert Otel.API.Trace.TraceId.to_hex(tid) == "00000000000000000000000000000001"
    end
  end

  describe "round-trip" do
    test "bytes → hex → bytes" do
      tid = Otel.API.Trace.TraceId.new(@valid_bytes)
      hex = Otel.API.Trace.TraceId.to_hex(tid)
      assert Otel.API.Trace.TraceId.from_hex(hex).bytes == @valid_bytes
    end
  end

  describe "invalid/0 and valid?/1" do
    test "invalid/0 returns all-zero bytes" do
      assert Otel.API.Trace.TraceId.invalid() ==
               %Otel.API.Trace.TraceId{bytes: <<0::128>>}
    end

    test "valid?/1 is false for invalid" do
      refute Otel.API.Trace.TraceId.valid?(Otel.API.Trace.TraceId.invalid())
    end

    test "valid?/1 is true for any non-zero TraceId" do
      assert Otel.API.Trace.TraceId.valid?(Otel.API.Trace.TraceId.new(@valid_bytes))
    end

    test "valid?/1 is true when only the last byte is set" do
      assert Otel.API.Trace.TraceId.valid?(Otel.API.Trace.TraceId.new(<<0::120, 1::8>>))
    end
  end
end
