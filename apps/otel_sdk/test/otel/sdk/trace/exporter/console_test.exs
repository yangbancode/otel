defmodule Otel.SDK.Trace.Exporter.ConsoleTest do
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

  describe "init/1" do
    test "returns {:ok, config}" do
      assert {:ok, %{}} = Otel.SDK.Trace.Exporter.Console.init(%{})
    end
  end

  describe "export/3" do
    test "prints spans to stdout" do
      output =
        capture_io(fn ->
          assert :ok = Otel.SDK.Trace.Exporter.Console.export([@span], %{}, %{})
        end)

      assert output =~ "test_span"
      assert output =~ "trace_id="
      assert output =~ "span_id="
    end

    test "includes trace_id as 32-char hex" do
      output =
        capture_io(fn ->
          Otel.SDK.Trace.Exporter.Console.export([@span], %{}, %{})
        end)

      assert output =~ "trace_id=ff000000000000000000000000000001"
    end

    test "includes span_id as 16-char hex" do
      output =
        capture_io(fn ->
          Otel.SDK.Trace.Exporter.Console.export([@span], %{}, %{})
        end)

      assert output =~ "span_id=ff00000000000001"
    end

    test "shows parent=none for root span" do
      output =
        capture_io(fn ->
          Otel.SDK.Trace.Exporter.Console.export([@span], %{}, %{})
        end)

      assert output =~ "parent=none"
    end

    test "shows parent span_id for child span" do
      child = %{@span | parent_span_id: 0xAA00000000000001}

      output =
        capture_io(fn ->
          Otel.SDK.Trace.Exporter.Console.export([child], %{}, %{})
        end)

      assert output =~ "parent=aa00000000000001"
    end

    test "includes attributes" do
      output =
        capture_io(fn ->
          Otel.SDK.Trace.Exporter.Console.export([@span], %{}, %{})
        end)

      assert output =~ "key"
      assert output =~ "value"
    end

    test "exports multiple spans" do
      span2 = %{@span | name: "second_span", span_id: 2}

      output =
        capture_io(fn ->
          Otel.SDK.Trace.Exporter.Console.export([@span, span2], %{}, %{})
        end)

      assert output =~ "test_span"
      assert output =~ "second_span"
    end
  end

  describe "shutdown/1" do
    test "returns :ok" do
      assert :ok = Otel.SDK.Trace.Exporter.Console.shutdown(%{})
    end
  end
end
