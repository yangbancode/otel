# credo:disable-for-this-file Credo.Check.Refactor.Apply
defmodule Otel.API.Common.AttributeTest do
  use ExUnit.Case, async: true

  describe "new/2" do
    test "builds an attribute with a string-valued AnyValue" do
      value = Otel.API.Common.AnyValue.string("GET")
      attr = Otel.API.Common.Attribute.new("http.method", value)
      assert attr.key == "http.method"
      assert attr.value == value
    end

    test "accepts any AnyValue variant" do
      for v <- [
            Otel.API.Common.AnyValue.string("x"),
            Otel.API.Common.AnyValue.bool(true),
            Otel.API.Common.AnyValue.int(42),
            Otel.API.Common.AnyValue.double(1.5),
            Otel.API.Common.AnyValue.bytes(<<1, 2>>),
            Otel.API.Common.AnyValue.array([]),
            Otel.API.Common.AnyValue.kvlist(%{}),
            Otel.API.Common.AnyValue.empty()
          ] do
        assert %Otel.API.Common.Attribute{} = Otel.API.Common.Attribute.new("k", v)
      end
    end

    test "rejects native value (strict mode — no coercion)" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Common.Attribute, :new, ["k", "raw string"])
      end

      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Common.Attribute, :new, ["k", 42])
      end
    end

    test "rejects empty key" do
      assert_raise ArgumentError, fn ->
        Otel.API.Common.Attribute.new("", Otel.API.Common.AnyValue.string("v"))
      end
    end

    test "rejects non-string key" do
      assert_raise FunctionClauseError, fn ->
        apply(Otel.API.Common.Attribute, :new, [:atom_key, Otel.API.Common.AnyValue.string("v")])
      end
    end

    test "rejects non-UTF-8 binary key" do
      assert_raise ArgumentError, fn ->
        Otel.API.Common.Attribute.new(<<0xFF, 0xFE>>, Otel.API.Common.AnyValue.string("v"))
      end
    end
  end

  describe "valid?/1" do
    test "returns true for a well-formed Attribute" do
      attr = Otel.API.Common.Attribute.new("k", Otel.API.Common.AnyValue.string("v"))
      assert Otel.API.Common.Attribute.valid?(attr)
    end

    test "returns false for an Attribute with empty key" do
      bad = %Otel.API.Common.Attribute{key: "", value: Otel.API.Common.AnyValue.string("v")}
      refute Otel.API.Common.Attribute.valid?(bad)
    end

    test "returns false for an Attribute with non-AnyValue value" do
      bad = %Otel.API.Common.Attribute{key: "k", value: "raw"}
      refute Otel.API.Common.Attribute.valid?(bad)
    end

    test "returns false for non-struct terms" do
      refute Otel.API.Common.Attribute.valid?(%{key: "k", value: "v"})
      refute Otel.API.Common.Attribute.valid?(nil)
      refute Otel.API.Common.Attribute.valid?("x")
    end
  end
end
