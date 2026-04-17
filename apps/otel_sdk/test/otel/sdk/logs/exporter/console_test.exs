defmodule Otel.SDK.Logs.Exporter.ConsoleTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @record %{
    body: "Hello, world!",
    severity_number: 9,
    severity_text: "INFO",
    attributes: %{"method" => "GET"},
    scope: %Otel.API.InstrumentationScope{name: "test_lib"},
    resource: Otel.SDK.Resource.create(%{}),
    trace_id: 0,
    span_id: 0,
    trace_flags: 0,
    timestamp: nil,
    observed_timestamp: 1_000_000,
    event_name: nil,
    dropped_attributes_count: 0
  }

  describe "init/1" do
    test "returns {:ok, config}" do
      assert {:ok, %{}} = Otel.SDK.Logs.Exporter.Console.init(%{})
    end
  end

  describe "export/2" do
    test "outputs log record to stdout" do
      output =
        capture_io(fn ->
          Otel.SDK.Logs.Exporter.Console.export([@record], %{})
        end)

      assert output =~ "[otel]"
      assert output =~ "INFO"
      assert output =~ "scope=test_lib"
      assert output =~ "Hello, world!"
      assert output =~ "method"
    end

    test "outputs multiple records" do
      record2 = %{@record | body: "Second log", severity_text: "ERROR", severity_number: 17}

      output =
        capture_io(fn ->
          Otel.SDK.Logs.Exporter.Console.export([@record, record2], %{})
        end)

      assert output =~ "Hello, world!"
      assert output =~ "Second log"
    end

    test "returns :ok" do
      output =
        capture_io(fn ->
          assert :ok == Otel.SDK.Logs.Exporter.Console.export([@record], %{})
        end)

      assert output != ""
    end

    test "shows severity number when no text" do
      record = %{@record | severity_text: nil, severity_number: 5}

      output =
        capture_io(fn ->
          Otel.SDK.Logs.Exporter.Console.export([record], %{})
        end)

      assert output =~ "severity=5"
    end

    test "shows UNSPECIFIED when no severity" do
      record = %{@record | severity_text: nil, severity_number: nil}

      output =
        capture_io(fn ->
          Otel.SDK.Logs.Exporter.Console.export([record], %{})
        end)

      assert output =~ "UNSPECIFIED"
    end

    test "includes trace context when present" do
      record = %{
        @record
        | trace_id: 0x0AF7651916CD43DD8448EB211C80319C,
          span_id: 0xB7AD6B7169203331
      }

      output =
        capture_io(fn ->
          Otel.SDK.Logs.Exporter.Console.export([record], %{})
        end)

      assert output =~ "trace="
      assert output =~ "span="
    end

    test "omits trace context when zero" do
      output =
        capture_io(fn ->
          Otel.SDK.Logs.Exporter.Console.export([@record], %{})
        end)

      refute output =~ "trace="
    end
  end

  describe "force_flush/1" do
    test "returns :ok" do
      assert :ok == Otel.SDK.Logs.Exporter.Console.force_flush(%{})
    end
  end

  describe "shutdown/1" do
    test "returns :ok" do
      assert :ok == Otel.SDK.Logs.Exporter.Console.shutdown(%{})
    end
  end
end
