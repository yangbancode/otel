defmodule Otel.SDK.Logs.LogRecordLimitsTest do
  use ExUnit.Case, async: true

  describe "defaults" do
    test "attribute_count_limit is 128" do
      assert %Otel.SDK.Logs.LogRecordLimits{}.attribute_count_limit == 128
    end

    test "attribute_value_length_limit is :infinity" do
      assert %Otel.SDK.Logs.LogRecordLimits{}.attribute_value_length_limit == :infinity
    end
  end

  describe "apply/2 — pass-through" do
    test "returns the record unchanged with zero dropped count when both limits satisfied" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{a: 1, b: "short", c: true}}
      limits = %Otel.SDK.Logs.LogRecordLimits{}
      assert Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits) == {log_record, 0}
    end

    test "preserves non-attribute fields when limits trigger" do
      log_record = %Otel.API.Logs.LogRecord{
        timestamp: 12_345,
        severity_number: 9,
        severity_text: "info",
        body: "hello",
        attributes: %{a: 1, b: 2, c: 3},
        event_name: "ev"
      }

      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 1}
      {result, dropped_attributes_count} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)

      assert result.timestamp == log_record.timestamp
      assert result.severity_number == log_record.severity_number
      assert result.severity_text == log_record.severity_text
      assert result.body == log_record.body
      assert result.event_name == log_record.event_name
      assert map_size(result.attributes) == 1
      assert dropped_attributes_count == 2
    end

    test "empty attributes returns empty with zero dropped" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{}}
      limits = %Otel.SDK.Logs.LogRecordLimits{}
      {result, dropped_attributes_count} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes == %{}
      assert dropped_attributes_count == 0
    end
  end

  describe "apply/2 — value length limit" do
    test "truncates string values exceeding limit" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{key: "abcdefgh"}}
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 5}
      {result, dropped_attributes_count} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes.key == "abcde"
      assert dropped_attributes_count == 0
    end

    test "does not truncate strings within limit" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{key: "short"}}
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 10}
      {result, dropped_attributes_count} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes.key == "short"
      assert dropped_attributes_count == 0
    end

    test "truncates strings inside lists element-wise" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{key: ["abcdef", "xy", "123456"]}}
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 3}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes.key == ["abc", "xy", "123"]
    end

    test "passes non-string values through unchanged" do
      log_record = %Otel.API.Logs.LogRecord{
        attributes: %{int: 12_345, float: 3.14, bool: true, nil_val: nil}
      }

      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 1}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes == log_record.attributes
    end

    test "truncates {:bytes, _} by byte size" do
      log_record = %Otel.API.Logs.LogRecord{
        attributes: %{key: {:bytes, <<255, 254, 253, 252, 251>>}}
      }

      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 3}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes.key == {:bytes, <<255, 254, 253>>}
    end

    test "does not truncate {:bytes, _} within limit" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{key: {:bytes, <<1, 2, 3>>}}}
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 10}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes.key == {:bytes, <<1, 2, 3>>}
    end

    test "truncates {:bytes, _} inside lists" do
      log_record = %Otel.API.Logs.LogRecord{
        attributes: %{key: [{:bytes, <<1, 2, 3, 4>>}, {:bytes, <<9, 8>>}]}
      }

      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 2}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes.key == [{:bytes, <<1, 2>>}, {:bytes, <<9, 8>>}]
    end

    test "byte truncation uses bytes, not characters" do
      # "한" is 3 bytes in UTF-8 but 1 character; tagged as :bytes,
      # the limit applies to bytes (truncates mid-codepoint).
      log_record = %Otel.API.Logs.LogRecord{attributes: %{key: {:bytes, "한"}}}
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 2}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes.key == {:bytes, binary_part("한", 0, 2)}
    end

    test ":infinity skips truncation" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{key: String.duplicate("a", 1000)}}
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: :infinity}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes == log_record.attributes
    end

    test "value length limit 0 truncates strings to empty" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{key: "non-empty"}}
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 0}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes.key == ""
    end

    test "value length limit 0 truncates bytes to empty" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{key: {:bytes, <<1, 2, 3>>}}}
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 0}
      {result, _dropped} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes.key == {:bytes, <<>>}
    end
  end

  describe "apply/2 — count limit" do
    test "drops excess attributes and reports the dropped count" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{a: 1, b: 2, c: 3, d: 4}}
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 2}
      {result, dropped_attributes_count} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert map_size(result.attributes) == 2
      assert dropped_attributes_count == 2
    end

    test "passes through when exactly at count limit" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{a: 1, b: 2, c: 3}}
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 3}
      {result, dropped_attributes_count} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes == log_record.attributes
      assert dropped_attributes_count == 0
    end

    test "count limit 0 drops all attributes" do
      log_record = %Otel.API.Logs.LogRecord{attributes: %{a: 1, b: 2}}
      limits = %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 0}
      {result, dropped_attributes_count} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert result.attributes == %{}
      assert dropped_attributes_count == 2
    end
  end

  describe "apply/2 — both limits" do
    test "applies value length limit before count limit" do
      log_record = %Otel.API.Logs.LogRecord{
        attributes: %{a: "abcdef", b: "xyz", c: "123456"}
      }

      limits = %Otel.SDK.Logs.LogRecordLimits{
        attribute_count_limit: 2,
        attribute_value_length_limit: 3
      }

      {result, dropped_attributes_count} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits)
      assert map_size(result.attributes) == 2
      assert dropped_attributes_count == 1

      Enum.each(result.attributes, fn {_key, value} ->
        assert String.length(value) <= 3
      end)
    end
  end
end
