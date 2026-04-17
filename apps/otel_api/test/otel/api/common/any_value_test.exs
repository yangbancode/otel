# credo:disable-for-this-file Credo.Check.Refactor.Apply
defmodule Otel.API.Common.AnyValueTest do
  use ExUnit.Case, async: true

  describe "string/1" do
    test "builds a :string variant" do
      v = Otel.API.Common.AnyValue.string("hello")
      assert v == %Otel.API.Common.AnyValue{type: :string, value: "hello"}
    end

    test "accepts empty string" do
      assert Otel.API.Common.AnyValue.string("").value == ""
    end

    test "raises on non-UTF-8 binary" do
      assert_raise ArgumentError, fn ->
        Otel.API.Common.AnyValue.string(<<0xFF, 0xFE>>)
      end
    end

    test "raises on non-binary" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Common.AnyValue, :string, [42])
      end
    end
  end

  describe "bool/1" do
    test "builds true" do
      assert Otel.API.Common.AnyValue.bool(true) ==
               %Otel.API.Common.AnyValue{type: :bool, value: true}
    end

    test "builds false" do
      assert Otel.API.Common.AnyValue.bool(false) ==
               %Otel.API.Common.AnyValue{type: :bool, value: false}
    end

    test "raises on non-boolean" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Common.AnyValue, :bool, [1])
      end
    end
  end

  describe "int/1" do
    test "builds a :int variant" do
      assert Otel.API.Common.AnyValue.int(42) ==
               %Otel.API.Common.AnyValue{type: :int, value: 42}
    end

    test "accepts zero" do
      assert Otel.API.Common.AnyValue.int(0).value == 0
    end

    test "accepts int64 min" do
      min = -0x8000_0000_0000_0000
      assert Otel.API.Common.AnyValue.int(min).value == min
    end

    test "accepts int64 max" do
      max = 0x7FFF_FFFF_FFFF_FFFF
      assert Otel.API.Common.AnyValue.int(max).value == max
    end

    test "rejects value above int64 max" do
      assert_raise FunctionClauseError, fn ->
        Otel.API.Common.AnyValue.int(0x8000_0000_0000_0000)
      end
    end

    test "rejects value below int64 min" do
      assert_raise FunctionClauseError, fn ->
        Otel.API.Common.AnyValue.int(-0x8000_0000_0000_0001)
      end
    end

    test "rejects float" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Common.AnyValue, :int, [1.5])
      end
    end
  end

  describe "double/1" do
    test "builds a :double variant" do
      assert Otel.API.Common.AnyValue.double(3.14) ==
               %Otel.API.Common.AnyValue{type: :double, value: 3.14}
    end

    test "rejects integer" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Common.AnyValue, :double, [1])
      end
    end
  end

  describe "bytes/1" do
    test "builds a :bytes variant" do
      assert Otel.API.Common.AnyValue.bytes(<<1, 2, 3>>) ==
               %Otel.API.Common.AnyValue{type: :bytes, value: <<1, 2, 3>>}
    end

    test "accepts non-UTF-8 binary" do
      assert Otel.API.Common.AnyValue.bytes(<<0xFF, 0xFE>>).value == <<0xFF, 0xFE>>
    end

    test "accepts empty binary" do
      assert Otel.API.Common.AnyValue.bytes("").value == ""
    end
  end

  describe "array/1" do
    test "builds an :array variant with AnyValue elements" do
      elements = [
        Otel.API.Common.AnyValue.string("a"),
        Otel.API.Common.AnyValue.int(1)
      ]

      v = Otel.API.Common.AnyValue.array(elements)
      assert v.type == :array
      assert v.value == elements
    end

    test "accepts empty list" do
      assert Otel.API.Common.AnyValue.array([]).value == []
    end

    test "rejects list containing non-AnyValue elements" do
      assert_raise ArgumentError, fn ->
        Otel.API.Common.AnyValue.array([Otel.API.Common.AnyValue.string("a"), "raw"])
      end
    end

    test "rejects non-list" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Common.AnyValue, :array, [%{}])
      end
    end
  end

  describe "kvlist/1" do
    test "builds a :kvlist variant" do
      m = %{"k" => Otel.API.Common.AnyValue.string("v")}
      v = Otel.API.Common.AnyValue.kvlist(m)
      assert v.type == :kvlist
      assert v.value == m
    end

    test "accepts empty map" do
      assert Otel.API.Common.AnyValue.kvlist(%{}).value == %{}
    end

    test "rejects non-string key" do
      assert_raise ArgumentError, fn ->
        Otel.API.Common.AnyValue.kvlist(%{:atom => Otel.API.Common.AnyValue.string("v")})
      end
    end

    test "rejects empty-string key" do
      assert_raise ArgumentError, fn ->
        Otel.API.Common.AnyValue.kvlist(%{"" => Otel.API.Common.AnyValue.string("v")})
      end
    end

    test "rejects non-AnyValue value" do
      assert_raise ArgumentError, fn ->
        apply(Otel.API.Common.AnyValue, :kvlist, [%{"k" => "raw"}])
      end
    end
  end

  describe "empty/0" do
    test "builds an :empty variant" do
      assert Otel.API.Common.AnyValue.empty() ==
               %Otel.API.Common.AnyValue{type: :empty, value: nil}
    end
  end

  describe "valid?/1" do
    test "returns true for each variant" do
      assert Otel.API.Common.AnyValue.valid?(Otel.API.Common.AnyValue.string("x"))
      assert Otel.API.Common.AnyValue.valid?(Otel.API.Common.AnyValue.bool(true))
      assert Otel.API.Common.AnyValue.valid?(Otel.API.Common.AnyValue.int(1))
      assert Otel.API.Common.AnyValue.valid?(Otel.API.Common.AnyValue.double(1.0))
      assert Otel.API.Common.AnyValue.valid?(Otel.API.Common.AnyValue.bytes("x"))
      assert Otel.API.Common.AnyValue.valid?(Otel.API.Common.AnyValue.array([]))
      assert Otel.API.Common.AnyValue.valid?(Otel.API.Common.AnyValue.kvlist(%{}))
      assert Otel.API.Common.AnyValue.valid?(Otel.API.Common.AnyValue.empty())
    end

    test "returns false for non-struct terms" do
      refute Otel.API.Common.AnyValue.valid?("string")
      refute Otel.API.Common.AnyValue.valid?(nil)
      refute Otel.API.Common.AnyValue.valid?(%{type: :string, value: "x"})
    end

    test "returns false for struct with unknown tag" do
      refute Otel.API.Common.AnyValue.valid?(%Otel.API.Common.AnyValue{
               type: :unknown,
               value: nil
             })
    end
  end
end
