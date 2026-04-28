defmodule Otel.SDK.Trace.SpanExporter.ConsoleTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @span %Otel.SDK.Trace.Span{
    trace_id: 0xFF000000000000000000000000000001,
    span_id: 0xFF00000000000001,
    name: "test_span",
    kind: :internal,
    start_time: 1_000_000_000,
    attributes: %{"key" => "value"},
    trace_flags: 1,
    is_recording: true
  }

  defp render(spans),
    do: capture_io(fn -> Otel.SDK.Trace.SpanExporter.Console.export(spans, %{}, %{}) end)

  test "init/1 + shutdown/1 + force_flush/1 round-trip with the documented success shape" do
    assert {:ok, %{}} = Otel.SDK.Trace.SpanExporter.Console.init(%{})
    assert :ok = Otel.SDK.Trace.SpanExporter.Console.shutdown(%{})
    assert :ok = Otel.SDK.Trace.SpanExporter.Console.force_flush(%{})
  end

  describe "export/3 — formatted output" do
    test "single span renders name, hex trace_id/span_id, and attributes" do
      output = render([@span])

      assert output =~ "test_span"
      assert output =~ "trace_id=ff000000000000000000000000000001"
      assert output =~ "span_id=ff00000000000001"
      assert output =~ "key"
      assert output =~ "value"
    end

    test "root span shows parent=none; child span shows parent=<hex>" do
      assert render([@span]) =~ "parent=none"

      assert render([%{@span | parent_span_id: 0xAA00000000000001}]) =~
               "parent=aa00000000000001"
    end

    test "exports multiple spans in one call" do
      output = render([@span, %{@span | name: "second_span", span_id: 2}])

      assert output =~ "test_span"
      assert output =~ "second_span"
    end
  end
end
