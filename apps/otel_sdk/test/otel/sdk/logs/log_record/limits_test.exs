defmodule Otel.SDK.Logs.LogRecord.LimitsTest do
  use ExUnit.Case, async: true

  describe "defaults" do
    test "attribute_count_limit is 128" do
      assert %Otel.SDK.Logs.LogRecord.Limits{}.attribute_count_limit == 128
    end

    test "attribute_value_length_limit is :infinity" do
      assert %Otel.SDK.Logs.LogRecord.Limits{}.attribute_value_length_limit == :infinity
    end
  end

  describe "truncate_attributes/2" do
    test ":infinity passes through" do
      attrs = %{key: String.duplicate("a", 1000)}
      assert Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(attrs, :infinity) == attrs
    end

    test "truncates string values exceeding limit" do
      attrs = %{key: "abcdefgh"}
      result = Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(attrs, 5)
      assert result.key == "abcde"
    end

    test "does not truncate strings within limit" do
      attrs = %{key: "short"}
      assert Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(attrs, 10) == attrs
    end

    test "truncates strings in lists element-wise" do
      attrs = %{key: ["abcdef", "xy", "123456"]}
      result = Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(attrs, 3)
      assert result.key == ["abc", "xy", "123"]
    end

    test "passes non-string values through unchanged" do
      attrs = %{int: 12_345, float: 3.14, bool: true, nil_val: nil}
      result = Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(attrs, 1)
      assert result == attrs
    end

    test "truncates {:bytes, _} by byte size" do
      attrs = %{key: {:bytes, <<255, 254, 253, 252, 251>>}}
      result = Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(attrs, 3)
      assert result.key == {:bytes, <<255, 254, 253>>}
    end

    test "does not truncate {:bytes, _} within limit" do
      attrs = %{key: {:bytes, <<1, 2, 3>>}}
      assert Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(attrs, 10) == attrs
    end

    test "truncates {:bytes, _} inside lists" do
      attrs = %{key: [{:bytes, <<1, 2, 3, 4>>}, {:bytes, <<9, 8>>}]}
      result = Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(attrs, 2)
      assert result.key == [{:bytes, <<1, 2>>}, {:bytes, <<9, 8>>}]
    end

    test "byte truncation uses bytes, not characters" do
      # "한" is 3 bytes in UTF-8 but 1 character; tagged as :bytes,
      # the limit applies to bytes (truncates mid-codepoint).
      attrs = %{key: {:bytes, "한"}}
      result = Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(attrs, 2)
      assert result.key == {:bytes, binary_part("한", 0, 2)}
    end

    test "limit 0 truncates strings to empty" do
      result = Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(%{key: "non-empty"}, 0)
      assert result.key == ""
    end

    test "limit 0 truncates bytes to empty" do
      result = Otel.SDK.Logs.LogRecord.Limits.truncate_attributes(%{key: {:bytes, <<1, 2>>}}, 0)
      assert result.key == {:bytes, <<>>}
    end
  end

  describe "drop_attributes/2" do
    test "passes through when within limit" do
      attrs = %{a: 1, b: 2, c: 3}
      assert Otel.SDK.Logs.LogRecord.Limits.drop_attributes(attrs, 128) == attrs
    end

    test "passes through when exactly at limit" do
      attrs = %{a: 1, b: 2, c: 3}
      assert Otel.SDK.Logs.LogRecord.Limits.drop_attributes(attrs, 3) == attrs
    end

    test "drops excess attributes" do
      attrs = %{a: 1, b: 2, c: 3, d: 4}
      result = Otel.SDK.Logs.LogRecord.Limits.drop_attributes(attrs, 2)
      assert map_size(result) == 2
    end

    test "empty attributes returns empty" do
      assert Otel.SDK.Logs.LogRecord.Limits.drop_attributes(%{}, 128) == %{}
    end

    test "limit 0 drops all attributes" do
      assert Otel.SDK.Logs.LogRecord.Limits.drop_attributes(%{a: 1, b: 2}, 0) == %{}
    end
  end
end
