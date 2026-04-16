defmodule Otel.SDK.Logs.LogRecordLimitsTest do
  use ExUnit.Case, async: true

  @default_limits %Otel.SDK.Logs.LogRecordLimits{}

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
      attrs = %{a: 1, b: 2, c: 3}
      {result, dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, @default_limits)
      assert result == attrs
      assert dropped == 0
    end

    test "discards excess attributes" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 2}
      attrs = %{a: 1, b: 2, c: 3, d: 4}
      {result, dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert map_size(result) == 2
      assert dropped == 2
    end

    test "returns 0 dropped when exactly at limit" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 3}
      attrs = %{a: 1, b: 2, c: 3}
      {result, dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert map_size(result) == 3
      assert dropped == 0
    end

    test "empty attributes returns empty" do
      {result, dropped} = Otel.SDK.Logs.LogRecordLimits.apply(%{}, @default_limits)
      assert result == %{}
      assert dropped == 0
    end
  end

  describe "apply/2 value truncation" do
    test "no truncation with :infinity limit" do
      attrs = %{key: String.duplicate("a", 1000)}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, @default_limits)
      assert String.length(result.key) == 1000
    end

    test "truncates string values exceeding limit" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 5}
      attrs = %{key: "abcdefgh"}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert result.key == "abcde"
    end

    test "does not truncate strings within limit" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 10}
      attrs = %{key: "short"}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert result.key == "short"
    end

    test "truncates strings in lists" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 3}
      attrs = %{key: ["abcdef", "xy", "123456"]}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert result.key == ["abc", "xy", "123"]
    end

    test "does not truncate non-string values" do
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 1}
      attrs = %{int: 12_345, float: 3.14, bool: true}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert result.int == 12_345
      assert result.float == 3.14
      assert result.bool == true
    end
  end

  describe "apply/2 both limits" do
    test "applies both count and value limits" do
      limits = %Otel.SDK.Logs.LogRecordLimits{
        attribute_count_limit: 2,
        attribute_value_length_limit: 3
      }

      attrs = %{a: "abcdef", b: "xyz", c: "123456"}
      {result, dropped} = Otel.SDK.Logs.LogRecordLimits.apply(attrs, limits)
      assert map_size(result) == 2
      assert dropped == 1

      Enum.each(result, fn {_key, value} ->
        assert String.length(value) <= 3
      end)
    end
  end
end
