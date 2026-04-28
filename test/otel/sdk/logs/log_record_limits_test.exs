defmodule Otel.SDK.Logs.LogRecordLimitsTest do
  use ExUnit.Case, async: true

  defp record(attrs), do: %Otel.API.Logs.LogRecord{attributes: attrs}
  defp limits(opts \\ []), do: struct(%Otel.SDK.Logs.LogRecordLimits{}, opts)

  test "default limits — attribute_count_limit 128, attribute_value_length_limit :infinity" do
    assert %Otel.SDK.Logs.LogRecordLimits{} == %Otel.SDK.Logs.LogRecordLimits{
             attribute_count_limit: 128,
             attribute_value_length_limit: :infinity
           }
  end

  describe "apply/2 — pass-through" do
    test "returns the record unchanged with 0 dropped when both limits are satisfied" do
      log_record = record(%{a: 1, b: "short", c: true})
      assert {^log_record, 0} = Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits())
    end

    test "preserves non-attribute fields when count limit triggers" do
      log_record = %Otel.API.Logs.LogRecord{
        timestamp: 12_345,
        severity_number: 9,
        severity_text: "info",
        body: "hello",
        attributes: %{a: 1, b: 2, c: 3},
        event_name: "ev"
      }

      {result, dropped} =
        Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits(attribute_count_limit: 1))

      assert result.timestamp == log_record.timestamp
      assert result.severity_number == log_record.severity_number
      assert result.severity_text == log_record.severity_text
      assert result.body == log_record.body
      assert result.event_name == log_record.event_name
      assert map_size(result.attributes) == 1
      assert dropped == 2
    end
  end

  describe "apply/2 — attribute_value_length_limit" do
    test "truncates strings; passes non-strings through; :infinity skips" do
      {r, 0} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{key: "abcdefgh"}),
          limits(attribute_value_length_limit: 5)
        )

      assert r.attributes.key == "abcde"

      {r, 0} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{key: "short"}),
          limits(attribute_value_length_limit: 10)
        )

      assert r.attributes.key == "short"

      {r, 0} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{int: 12_345, float: 3.14, bool: true, nil_val: nil}),
          limits(attribute_value_length_limit: 1)
        )

      assert r.attributes == %{int: 12_345, float: 3.14, bool: true, nil_val: nil}

      {r, 0} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{key: String.duplicate("a", 1000)}),
          limits(attribute_value_length_limit: :infinity)
        )

      assert r.attributes.key == String.duplicate("a", 1000)
    end

    test "truncates strings inside primitive arrays element-wise" do
      {r, _} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{key: ["abcdef", "xy", "123456"]}),
          limits(attribute_value_length_limit: 3)
        )

      assert r.attributes.key == ["abc", "xy", "123"]
    end

    # {:bytes, _} tagged values truncate by byte count, not character.
    test "{:bytes, _} truncates by byte size, including inside arrays" do
      {r, _} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{key: {:bytes, <<255, 254, 253, 252, 251>>}}),
          limits(attribute_value_length_limit: 3)
        )

      assert r.attributes.key == {:bytes, <<255, 254, 253>>}

      # Within limit → unchanged.
      {r, _} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{key: {:bytes, <<1, 2, 3>>}}),
          limits(attribute_value_length_limit: 10)
        )

      assert r.attributes.key == {:bytes, <<1, 2, 3>>}

      # Inside arrays.
      {r, _} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{key: [{:bytes, <<1, 2, 3, 4>>}, {:bytes, <<9, 8>>}]}),
          limits(attribute_value_length_limit: 2)
        )

      assert r.attributes.key == [{:bytes, <<1, 2>>}, {:bytes, <<9, 8>>}]

      # "한" is 3 UTF-8 bytes; tagged :bytes, the limit applies to bytes
      # and may split mid-codepoint.
      {r, _} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{key: {:bytes, "한"}}),
          limits(attribute_value_length_limit: 2)
        )

      assert r.attributes.key == {:bytes, binary_part("한", 0, 2)}
    end

    test "limit 0 truncates strings to \"\" and bytes to <<>>" do
      {r, _} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{s: "non-empty", b: {:bytes, <<1, 2, 3>>}}),
          limits(attribute_value_length_limit: 0)
        )

      assert r.attributes == %{s: "", b: {:bytes, <<>>}}
    end

    # Spec logs/data-model.md L270-273 — AnyValue maps + heterogeneous
    # arrays recurse, truncating every nested string.
    test "truncates strings inside nested AnyValue maps and heterogeneous arrays" do
      log_record = %Otel.API.Logs.LogRecord{
        attributes: %{
          "envelope" => %{"name" => "abcdefghij", "nested" => %{"deep" => "wxyzabcdef"}},
          "items" => ["abcdefghij", 42, %{"k" => "abcdefghij"}, ["nestedString"]]
        }
      }

      {r, _} =
        Otel.SDK.Logs.LogRecordLimits.apply(log_record, limits(attribute_value_length_limit: 5))

      assert r.attributes == %{
               "envelope" => %{"name" => "abcde", "nested" => %{"deep" => "wxyza"}},
               "items" => ["abcde", 42, %{"k" => "abcde"}, ["neste"]]
             }
    end
  end

  describe "apply/2 — attribute_count_limit" do
    test "drops excess attributes; reports dropped count; pass-through at exact limit" do
      {r, 2} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{a: 1, b: 2, c: 3, d: 4}),
          limits(attribute_count_limit: 2)
        )

      assert map_size(r.attributes) == 2

      {r, 0} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{a: 1, b: 2, c: 3}),
          limits(attribute_count_limit: 3)
        )

      assert map_size(r.attributes) == 3

      {r, 2} =
        Otel.SDK.Logs.LogRecordLimits.apply(
          record(%{a: 1, b: 2}),
          limits(attribute_count_limit: 0)
        )

      assert r.attributes == %{}
    end
  end

  test "apply/2 — value length limit applies before count limit" do
    {r, 1} =
      Otel.SDK.Logs.LogRecordLimits.apply(
        record(%{a: "abcdef", b: "xyz", c: "123456"}),
        limits(attribute_count_limit: 2, attribute_value_length_limit: 3)
      )

    assert map_size(r.attributes) == 2

    for {_k, v} <- r.attributes do
      assert String.length(v) <= 3
    end
  end
end
