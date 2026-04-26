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

  describe "init/1" do
    test "returns {:ok, config}" do
      assert {:ok, %{}} = Otel.SDK.Logs.LogRecordExporter.Console.init(%{})
    end
  end

  describe "export/2" do
    test "outputs log record to stdout" do
      output =
        capture_io(fn ->
          Otel.SDK.Logs.LogRecordExporter.Console.export([@record], %{})
        end)

      assert output =~ "[otel]"
      assert output =~ "INFO (info)"
      assert output =~ "scope=test_lib"
      assert output =~ "Hello, world!"
      assert output =~ "method"
    end

    test "outputs multiple records" do
      record2 = %{@record | body: "Second log", severity_text: "error", severity_number: 17}

      output =
        capture_io(fn ->
          Otel.SDK.Logs.LogRecordExporter.Console.export([@record, record2], %{})
        end)

      assert output =~ "Hello, world!"
      assert output =~ "Second log"
      assert output =~ "ERROR (error)"
    end

    test "returns :ok" do
      output =
        capture_io(fn ->
          assert :ok == Otel.SDK.Logs.LogRecordExporter.Console.export([@record], %{})
        end)

      assert output != ""
    end

    test "shows short name only when severity_text is empty" do
      record = %{@record | severity_text: "", severity_number: 5}

      output =
        capture_io(fn ->
          Otel.SDK.Logs.LogRecordExporter.Console.export([record], %{})
        end)

      assert output =~ "DEBUG"
      refute output =~ "DEBUG ("
    end

    test "shows severity_text only when severity_number is zero" do
      record = %{@record | severity_text: "custom", severity_number: 0}

      output =
        capture_io(fn ->
          Otel.SDK.Logs.LogRecordExporter.Console.export([record], %{})
        end)

      assert output =~ "[otel] custom "
      refute output =~ "(custom)"
    end

    test "shows UNSPECIFIED when no severity" do
      record = %{@record | severity_text: "", severity_number: 0}

      output =
        capture_io(fn ->
          Otel.SDK.Logs.LogRecordExporter.Console.export([record], %{})
        end)

      assert output =~ "UNSPECIFIED"
    end

    test "covers full short-name table for severity_number 1..24" do
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
        record = %{@record | severity_text: "", severity_number: n}

        output =
          capture_io(fn ->
            Otel.SDK.Logs.LogRecordExporter.Console.export([record], %{})
          end)

        assert output =~ short, "expected #{short} for severity_number=#{n}"
      end
    end

    test "renders trace context hex when present" do
      record = %{
        @record
        | trace_id: 0x0AF7651916CD43DD8448EB211C80319C,
          span_id: 0xB7AD6B7169203331
      }

      output =
        capture_io(fn ->
          Otel.SDK.Logs.LogRecordExporter.Console.export([record], %{})
        end)

      assert output =~ "trace=0af7651916cd43dd8448eb211c80319c"
      assert output =~ "span=b7ad6b7169203331"
    end

    test "renders all-zeros trace context when no Context is active" do
      output =
        capture_io(fn ->
          Otel.SDK.Logs.LogRecordExporter.Console.export([@record], %{})
        end)

      assert output =~ "trace=00000000000000000000000000000000"
      assert output =~ "span=0000000000000000"
    end

    test "omits scope when name is empty" do
      record = %{@record | scope: %Otel.API.InstrumentationScope{name: ""}}

      output =
        capture_io(fn ->
          Otel.SDK.Logs.LogRecordExporter.Console.export([record], %{})
        end)

      refute output =~ "scope="
    end
  end

  describe "force_flush/1" do
    test "returns :ok" do
      assert :ok == Otel.SDK.Logs.LogRecordExporter.Console.force_flush(%{})
    end
  end

  describe "shutdown/1" do
    test "returns :ok" do
      assert :ok == Otel.SDK.Logs.LogRecordExporter.Console.shutdown(%{})
    end
  end
end
