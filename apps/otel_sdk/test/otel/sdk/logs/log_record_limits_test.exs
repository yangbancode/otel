defmodule Otel.SDK.Logs.LogRecordLimitsTest do
  use ExUnit.Case, async: true

  @default_limits %Otel.SDK.Logs.LogRecordLimits{}

  defp s(k, v) when is_binary(v) do
    Otel.API.Common.Attribute.new(k, Otel.API.Common.AnyValue.string(v))
  end

  defp i(k, v) when is_integer(v) do
    Otel.API.Common.Attribute.new(k, Otel.API.Common.AnyValue.int(v))
  end

  defp f(k, v) when is_float(v) do
    Otel.API.Common.Attribute.new(k, Otel.API.Common.AnyValue.double(v))
  end

  defp b(k, v) when is_boolean(v) do
    Otel.API.Common.Attribute.new(k, Otel.API.Common.AnyValue.bool(v))
  end

  defp value_of(attrs, key) do
    case Enum.find(attrs, &(&1.key == key)) do
      nil -> nil
      %Otel.API.Common.Attribute{value: %Otel.API.Common.AnyValue{value: v}} -> v
    end
  end

  describe "defaults" do
    test "attribute_count_limit is 128" do
      assert @default_limits.attribute_count_limit == 128
    end

    test "attribute_value_length_limit is :infinity" do
      assert @default_limits.attribute_value_length_limit == :infinity
    end
  end

  describe "apply/2 attribute count" do
    test "passes through when within limit" do
      attrs = [i("a", 1), i("b", 2), i("c", 3)]
      {result, dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, @default_limits)
      assert result == attrs
      assert dropped == 0
    end

    test "discards excess attributes" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 2}
      attrs = [i("a", 1), i("b", 2), i("c", 3), i("d", 4)]
      {result, dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert length(result) == 2
      assert dropped == 2
    end

    test "returns 0 dropped when exactly at limit" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 3}
      attrs = [i("a", 1), i("b", 2), i("c", 3)]
      {result, dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert length(result) == 3
      assert dropped == 0
    end

    test "empty attributes returns empty" do
      {result, dropped} = Otel.SDK.Logs.LogRecordLimits.apply([], @default_limits)
      assert result == []
      assert dropped == 0
    end
  end

  describe "apply/2 value truncation" do
    test "no truncation with :infinity limit" do
      attrs = [s("key", String.duplicate("a", 1000))]
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, @default_limits)
      assert String.length(value_of(result, "key")) == 1000
    end

    test "truncates string values exceeding limit" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 5}
      attrs = [s("key", "abcdefgh")]
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert value_of(result, "key") == "abcde"
    end

    test "does not truncate strings within limit" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 10}
      attrs = [s("key", "short")]
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert value_of(result, "key") == "short"
    end

    test "truncates strings in lists" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 3}

      array =
        Otel.API.Common.AnyValue.array([
          Otel.API.Common.AnyValue.string("abcdef"),
          Otel.API.Common.AnyValue.string("xy"),
          Otel.API.Common.AnyValue.string("123456")
        ])

      attrs = [Otel.API.Common.Attribute.new("key", array)]
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)

      %Otel.API.Common.AnyValue{value: items} =
        Enum.find(result, &(&1.key == "key")).value

      assert Enum.map(items, & &1.value) == ["abc", "xy", "123"]
    end

    test "does not truncate non-string values" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 1}
      attrs = [i("int", 12_345), f("float", 3.14), b("bool", true)]
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert value_of(result, "int") == 12_345
      assert value_of(result, "float") == 3.14
      assert value_of(result, "bool") == true
    end
  end

  describe "apply/2 both limits" do
    test "applies both count and value limits" do
      limits = %Otel.SDK.Logs.LogRecordLimits{
        attribute_count_limit: 2,
        attribute_value_length_limit: 3
      }

      attrs = [s("a", "abcdef"), s("b", "xyz"), s("c", "123456")]
      {result, dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert length(result) == 2
      assert dropped == 1

      Enum.each(result, fn %Otel.API.Common.Attribute{value: value} ->
        assert String.length(value.value) <= 3
      end)
    end
  end
end
