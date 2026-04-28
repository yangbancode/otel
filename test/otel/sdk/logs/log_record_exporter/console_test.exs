defmodule Otel.SDK.Logs.LogRecordExporter.ConsoleTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @record %Otel.SDK.Logs.LogRecord{
    body: "Hello, world!",
    severity_number: 9,
    severity_text: "info",
    attributes: %{"method" => "GET"},
    scope: %Otel.API.InstrumentationScope{name: "test_lib"},
    resource: Otel.SDK.Resource.create(%{}),
    trace_id: 0,
    span_id: 0,
    trace_flags: 0,
    timestamp: 0,
    observed_timestamp: 1_000_000,
    event_name: "",
    dropped_attributes_count: 0
  }

  defp render(records),
    do: capture_io(fn -> Otel.SDK.Logs.LogRecordExporter.Console.export(records, %{}) end)

  test "init/1 + shutdown/1 + force_flush/1 round-trip" do
    assert {:ok, %{}} = Otel.SDK.Logs.LogRecordExporter.Console.init(%{})
    assert :ok = Otel.SDK.Logs.LogRecordExporter.Console.shutdown(%{})
    assert :ok = Otel.SDK.Logs.LogRecordExporter.Console.force_flush(%{})
  end

  describe "export/2 — formatted output" do
    test "single record renders prefix, severity, scope, body, attributes" do
      output = render([@record])

      assert output =~ "[otel]"
      assert output =~ "INFO (info)"
      assert output =~ "scope=test_lib"
      assert output =~ "Hello, world!"
      assert output =~ "method"
    end

    test "exports multiple records in one call" do
      record2 = %{@record | body: "Second log", severity_text: "error", severity_number: 17}
      output = render([@record, record2])

      assert output =~ "Hello, world!"
      assert output =~ "Second log"
      assert output =~ "ERROR (error)"
    end

    test "trace context — hex when present, all-zeros placeholder when absent" do
      output_active =
        render([
          %{@record | trace_id: 0x0AF7651916CD43DD8448EB211C80319C, span_id: 0xB7AD6B7169203331}
        ])

      assert output_active =~ "trace=0af7651916cd43dd8448eb211c80319c"
      assert output_active =~ "span=b7ad6b7169203331"

      output_inactive = render([@record])
      assert output_inactive =~ "trace=00000000000000000000000000000000"
      assert output_inactive =~ "span=0000000000000000"
    end

    test "scope is omitted when the scope name is empty" do
      output = render([%{@record | scope: %Otel.API.InstrumentationScope{name: ""}}])
      refute output =~ "scope="
    end

    test "severity_number ↔ severity_text rendering matrix" do
      # Both set → "<short> (<text>)"; only number → short only;
      # only text → text only; neither → "UNSPECIFIED".
      assert render([%{@record | severity_text: "", severity_number: 5}]) =~ "DEBUG"
      refute render([%{@record | severity_text: "", severity_number: 5}]) =~ "DEBUG ("

      assert render([%{@record | severity_text: "custom", severity_number: 0}]) =~
               "[otel] custom "

      refute render([%{@record | severity_text: "custom", severity_number: 0}]) =~ "(custom)"

      assert render([%{@record | severity_text: "", severity_number: 0}]) =~ "UNSPECIFIED"
    end

    # Spec logs/data-model.md L121-L173 — severity_number 1..24 maps
    # to TRACE/TRACE2.../FATAL4 short names, repeating per family.
    test "covers the full short-name table for severity_number 1..24" do
      expected = %{
        1 => "TRACE",
        2 => "TRACE2",
        3 => "TRACE3",
        4 => "TRACE4",
        5 => "DEBUG",
        6 => "DEBUG2",
        7 => "DEBUG3",
        8 => "DEBUG4",
        9 => "INFO",
        10 => "INFO2",
        11 => "INFO3",
        12 => "INFO4",
        13 => "WARN",
        14 => "WARN2",
        15 => "WARN3",
        16 => "WARN4",
        17 => "ERROR",
        18 => "ERROR2",
        19 => "ERROR3",
        20 => "ERROR4",
        21 => "FATAL",
        22 => "FATAL2",
        23 => "FATAL3",
        24 => "FATAL4"
      }

      for {n, short} <- expected do
        assert render([%{@record | severity_text: "", severity_number: n}]) =~ short,
               "expected #{short} for severity_number=#{n}"
      end
    end
  end
end
