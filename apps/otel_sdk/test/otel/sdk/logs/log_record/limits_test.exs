defmodule Otel.SDK.Logs.LogRecord.LimitsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  @default_limits %Otel.SDK.Logs.LogRecord.Limits{}

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
      {result, dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, @default_limits)
      assert result == attrs
      assert dropped == 0
    end

    test "discards excess attributes" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_count_limit: 2}
      attrs = %{a: 1, b: 2, c: 3, d: 4}

      capture_log(fn ->
        {result, dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
        assert map_size(result) == 2
        assert dropped == 2
      end)
    end

    test "returns 0 dropped when exactly at limit" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_count_limit: 3}
      attrs = %{a: 1, b: 2, c: 3}
      {result, dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
      assert map_size(result) == 3
      assert dropped == 0
    end

    test "empty attributes returns empty" do
      {result, dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(%{}, @default_limits)
      assert result == %{}
      assert dropped == 0
    end
  end

  describe "apply/2 value truncation" do
    test "no truncation with :infinity limit" do
      attrs = %{key: String.duplicate("a", 1000)}
      {result, _dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, @default_limits)
      assert String.length(result.key) == 1000
    end

    test "truncates string values exceeding limit" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 5}
      attrs = %{key: "abcdefgh"}

      capture_log(fn ->
        {result, _dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
        assert result.key == "abcde"
      end)
    end

    test "does not truncate strings within limit" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 10}
      attrs = %{key: "short"}
      {result, _dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
      assert result.key == "short"
    end

    test "truncates strings in lists" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 3}
      attrs = %{key: ["abcdef", "xy", "123456"]}

      capture_log(fn ->
        {result, _dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
        assert result.key == ["abc", "xy", "123"]
      end)
    end

    test "does not truncate non-string values" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 1}
      attrs = %{int: 12_345, float: 3.14, bool: true}
      {result, _dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
      assert result.int == 12_345
      assert result.float == 3.14
      assert result.bool == true
    end

    test "truncates {:bytes, _} by byte size" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 3}
      attrs = %{key: {:bytes, <<255, 254, 253, 252, 251>>}}

      capture_log(fn ->
        {result, _dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
        assert result.key == {:bytes, <<255, 254, 253>>}
      end)
    end

    test "does not truncate {:bytes, _} within limit" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 10}
      attrs = %{key: {:bytes, <<1, 2, 3>>}}
      {result, _dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
      assert result.key == {:bytes, <<1, 2, 3>>}
    end

    test "truncates {:bytes, _} inside lists" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 2}
      attrs = %{key: [{:bytes, <<1, 2, 3, 4>>}, {:bytes, <<9, 8>>}]}

      capture_log(fn ->
        {result, _dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
        assert result.key == [{:bytes, <<1, 2>>}, {:bytes, <<9, 8>>}]
      end)
    end

    test "byte truncation uses bytes, not characters" do
      # "한" is 3 bytes in UTF-8 but 1 character; tagged as :bytes,
      # the limit applies to bytes (truncates mid-codepoint).
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 2}
      attrs = %{key: {:bytes, "한"}}

      capture_log(fn ->
        {result, _dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
        assert result.key == {:bytes, binary_part("한", 0, 2)}
      end)
    end
  end

  describe "apply/2 zero limits" do
    test "attribute_count_limit: 0 drops all attributes" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_count_limit: 0}
      attrs = %{a: 1, b: 2}

      capture_log(fn ->
        {result, dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
        assert result == %{}
        assert dropped == 2
      end)
    end

    test "attribute_value_length_limit: 0 truncates strings to empty" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 0}
      attrs = %{key: "non-empty"}

      capture_log(fn ->
        {result, _dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
        assert result.key == ""
      end)
    end

    test "attribute_value_length_limit: 0 truncates bytes to empty" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 0}
      attrs = %{key: {:bytes, <<1, 2, 3>>}}

      capture_log(fn ->
        {result, _dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
        assert result.key == {:bytes, <<>>}
      end)
    end
  end

  describe "apply/2 both limits" do
    test "applies both count and value limits" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{
        attribute_count_limit: 2,
        attribute_value_length_limit: 3
      }

      attrs = %{a: "abcdef", b: "xyz", c: "123456"}

      capture_log(fn ->
        {result, dropped} = Otel.SDK.Logs.LogRecord.Limits.apply(attrs, limits)
        assert map_size(result) == 2
        assert dropped == 1

        Enum.each(result, fn {_key, value} ->
          assert String.length(value) <= 3
        end)
      end)
    end
  end

  describe "apply/2 discard message" do
    test "logs warning when attributes are dropped" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_count_limit: 1}

      log =
        capture_log(fn ->
          Otel.SDK.Logs.LogRecord.Limits.apply(%{a: 1, b: 2, c: 3}, limits)
        end)

      assert log =~ "LogRecord limits applied"
      assert log =~ "dropped 2 attribute"
    end

    test "logs warning when values are truncated" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 3}

      log =
        capture_log(fn ->
          Otel.SDK.Logs.LogRecord.Limits.apply(%{key: "abcdefg"}, limits)
        end)

      assert log =~ "LogRecord limits applied"
      assert log =~ "truncated"
    end

    test "logs warning when bytes are truncated" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{attribute_value_length_limit: 2}

      log =
        capture_log(fn ->
          Otel.SDK.Logs.LogRecord.Limits.apply(%{key: {:bytes, <<1, 2, 3, 4>>}}, limits)
        end)

      assert log =~ "truncated"
    end

    test "logs single combined message when both dropped and truncated" do
      limits = %Otel.SDK.Logs.LogRecord.Limits{
        attribute_count_limit: 1,
        attribute_value_length_limit: 3
      }

      log =
        capture_log(fn ->
          Otel.SDK.Logs.LogRecord.Limits.apply(%{a: "abcdef", b: "ghijkl"}, limits)
        end)

      message_lines =
        log
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "LogRecord limits applied"))

      assert length(message_lines) == 1
      assert log =~ "dropped 1 attribute"
      assert log =~ "truncated"
    end

    test "does not log when within limits" do
      log =
        capture_log(fn ->
          Otel.SDK.Logs.LogRecord.Limits.apply(%{a: 1, b: "short"}, @default_limits)
        end)

      refute log =~ "LogRecord limits applied"
    end
  end
end
