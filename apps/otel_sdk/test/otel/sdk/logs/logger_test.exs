defmodule Otel.SDK.Logs.LoggerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  defmodule CollectorProcessor do
    @moduledoc false
    def on_emit(record, config) do
      send(config.test_pid, {:log_record, record})
      :ok
    end

    def shutdown(_config), do: :ok
    def force_flush(_config), do: :ok
  end

  defp start_logger_with_limits(limit_overrides) do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)

    limits = struct(Otel.SDK.Logs.LogRecordLimits, limit_overrides)

    {:ok, pid} =
      Otel.SDK.Logs.LoggerProvider.start_link(
        config: %{
          processors: [{CollectorProcessor, %{test_pid: self()}}],
          log_record_limits: limits
        }
      )

    {_mod, config} =
      Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{name: "lib"})

    {Otel.SDK.Logs.Logger, config}
  end

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)

    {:ok, pid} =
      Otel.SDK.Logs.LoggerProvider.start_link(
        config: %{
          processors: [{CollectorProcessor, %{test_pid: self()}}]
        }
      )

    {_module, logger_config} =
      Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{
        name: "test_lib",
        version: "1.0.0"
      })

    logger = {Otel.SDK.Logs.Logger, logger_config}

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :shutdown)
    end)

    %{logger: logger}
  end

  describe "emit/3" do
    test "dispatches to processor", %{logger: logger} do
      ctx = Otel.API.Ctx.current()
      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{body: "hello"})
      assert_receive {:log_record, record}
      assert record.body == "hello"
    end

    test "sets observed_timestamp when not provided", %{logger: logger} do
      ctx = Otel.API.Ctx.current()
      before = System.system_time(:nanosecond)
      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{body: "test"})
      assert_receive {:log_record, record}
      assert record.observed_timestamp >= before
    end

    test "preserves user-provided observed_timestamp", %{logger: logger} do
      ctx = Otel.API.Ctx.current()

      Otel.SDK.Logs.Logger.emit(
        logger,
        ctx,
        %Otel.API.Logs.LogRecord{body: "test", observed_timestamp: 42}
      )

      assert_receive {:log_record, record}
      assert record.observed_timestamp == 42
    end

    test "populates all proto3-default fields on empty record", %{logger: logger} do
      ctx = Otel.API.Ctx.current()
      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{})
      assert_receive {:log_record, record}
      assert record.timestamp == 0
      assert record.severity_number == 0
      assert record.severity_text == ""
      assert record.body == nil
      assert record.attributes == %{}
      assert record.event_name == ""
    end

    test "includes scope and resource", %{logger: logger} do
      ctx = Otel.API.Ctx.current()
      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{body: "scoped"})
      assert_receive {:log_record, record}
      assert record.scope.name == "test_lib"
      assert record.scope.version == "1.0.0"
      assert %Otel.SDK.Resource{} = record.resource
    end

    test "extracts trace context", %{logger: logger} do
      ctx = Otel.API.Ctx.current()
      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{body: "traced"})
      assert_receive {:log_record, record}
      assert Map.has_key?(record, :trace_id)
      assert Map.has_key?(record, :span_id)
      assert Map.has_key?(record, :trace_flags)
    end

    test "passes all user-provided fields through", %{logger: logger} do
      ctx = Otel.API.Ctx.current()

      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{
        timestamp: 1_000_000,
        severity_number: 9,
        severity_text: "INFO",
        body: "structured log",
        attributes: %{"method" => "GET", "status" => 200},
        event_name: "http.request"
      })

      assert_receive {:log_record, record}
      assert record.timestamp == 1_000_000
      assert record.severity_number == 9
      assert record.severity_text == "INFO"
      assert record.body == "structured log"
      assert record.attributes == %{"method" => "GET", "status" => 200}
      assert record.event_name == "http.request"
    end
  end

  describe "enabled?/2" do
    test "returns true when processors exist", %{logger: logger} do
      assert Otel.SDK.Logs.Logger.enabled?(logger, [])
    end

    test "returns false when no processors" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} = Otel.SDK.Logs.LoggerProvider.start_link(config: %{})

      {_mod, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{name: "lib"})

      logger = {Otel.SDK.Logs.Logger, config}

      refute Otel.SDK.Logs.Logger.enabled?(logger, [])
    end
  end

  describe "exception handling" do
    test "sets exception attributes from exception", %{logger: logger} do
      ctx = Otel.API.Ctx.current()
      exception = %RuntimeError{message: "something went wrong"}

      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{
        body: "error",
        exception: exception
      })

      assert_receive {:log_record, record}
      assert record.attributes["exception.type"] == "Elixir.RuntimeError"
      assert record.attributes["exception.message"] == "something went wrong"
    end

    test "user attributes take precedence over exception attributes", %{logger: logger} do
      ctx = Otel.API.Ctx.current()
      exception = %RuntimeError{message: "auto"}

      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{
        body: "error",
        exception: exception,
        attributes: %{"exception.message" => "user override"}
      })

      assert_receive {:log_record, record}
      assert record.attributes["exception.message"] == "user override"
      assert record.attributes["exception.type"] == "Elixir.RuntimeError"
    end

    test "no exception does not set exception attributes", %{logger: logger} do
      ctx = Otel.API.Ctx.current()
      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{body: "normal"})
      assert_receive {:log_record, record}
      refute Map.has_key?(record.attributes, "exception.type")
    end
  end

  describe "attribute limits" do
    test "truncates attribute values when limit set" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{CollectorProcessor, %{test_pid: self()}}],
            log_record_limits: %Otel.SDK.Logs.LogRecordLimits{attribute_value_length_limit: 5}
          }
        )

      {_mod, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{name: "lib"})

      logger = {Otel.SDK.Logs.Logger, config}

      ctx = Otel.API.Ctx.current()

      Otel.SDK.Logs.Logger.emit(
        logger,
        ctx,
        %Otel.API.Logs.LogRecord{attributes: %{"key" => "abcdefgh"}}
      )

      assert_receive {:log_record, record}
      assert record.attributes["key"] == "abcde"
    end

    test "drops excess attributes when count limit set" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      {:ok, pid} =
        Otel.SDK.Logs.LoggerProvider.start_link(
          config: %{
            processors: [{CollectorProcessor, %{test_pid: self()}}],
            log_record_limits: %Otel.SDK.Logs.LogRecordLimits{attribute_count_limit: 2}
          }
        )

      {_mod, config} =
        Otel.SDK.Logs.LoggerProvider.get_logger(pid, %Otel.API.InstrumentationScope{name: "lib"})

      logger = {Otel.SDK.Logs.Logger, config}

      ctx = Otel.API.Ctx.current()

      Otel.SDK.Logs.Logger.emit(logger, ctx, %Otel.API.Logs.LogRecord{
        attributes: %{"a" => 1, "b" => 2, "c" => 3, "d" => 4}
      })

      assert_receive {:log_record, record}
      assert map_size(record.attributes) == 2
      assert record.dropped_attributes_count == 2
    end

    test "dropped_attributes_count is 0 when within limit", %{logger: logger} do
      ctx = Otel.API.Ctx.current()

      Otel.SDK.Logs.Logger.emit(
        logger,
        ctx,
        %Otel.API.Logs.LogRecord{attributes: %{"a" => 1}}
      )

      assert_receive {:log_record, record}
      assert record.dropped_attributes_count == 0
    end

    test "warns when attributes are dropped", %{logger: _default_logger} do
      logger = start_logger_with_limits(%{attribute_count_limit: 1})
      ctx = Otel.API.Ctx.current()

      log =
        capture_log(fn ->
          Otel.SDK.Logs.Logger.emit(
            logger,
            ctx,
            %Otel.API.Logs.LogRecord{attributes: %{"a" => 1, "b" => 2, "c" => 3}}
          )
        end)

      assert log =~ "LogRecord limits applied"
      assert log =~ "dropped 2 attribute"
    end

    test "warns when values are truncated", %{logger: _default_logger} do
      logger = start_logger_with_limits(%{attribute_value_length_limit: 3})
      ctx = Otel.API.Ctx.current()

      log =
        capture_log(fn ->
          Otel.SDK.Logs.Logger.emit(
            logger,
            ctx,
            %Otel.API.Logs.LogRecord{attributes: %{"key" => "abcdefg"}}
          )
        end)

      assert log =~ "LogRecord limits applied"
      assert log =~ "truncated"
    end

    test "drop takes precedence in single message when both effects occur", %{
      logger: _default_logger
    } do
      logger =
        start_logger_with_limits(%{attribute_count_limit: 1, attribute_value_length_limit: 3})

      ctx = Otel.API.Ctx.current()

      log =
        capture_log(fn ->
          Otel.SDK.Logs.Logger.emit(
            logger,
            ctx,
            %Otel.API.Logs.LogRecord{attributes: %{"a" => "abcdef", "b" => "ghijkl"}}
          )
        end)

      message_lines =
        log
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "LogRecord limits applied"))

      assert length(message_lines) == 1
      assert log =~ "dropped 1 attribute"
      refute log =~ "truncated"
    end

    test "does not warn when within limits", %{logger: logger} do
      ctx = Otel.API.Ctx.current()

      log =
        capture_log(fn ->
          Otel.SDK.Logs.Logger.emit(
            logger,
            ctx,
            %Otel.API.Logs.LogRecord{attributes: %{"a" => 1, "b" => "short"}}
          )
        end)

      refute log =~ "LogRecord limits applied"
    end
  end

  describe "dispatch via API" do
    test "emit via API dispatch works", %{logger: logger} do
      Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{body: "via API"})
      assert_receive {:log_record, record}
      assert record.body == "via API"
    end
  end
end
