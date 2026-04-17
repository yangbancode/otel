defmodule Otel.API.Logs.LoggerTest do
  use ExUnit.Case, async: true

  @noop_logger {Otel.API.Logs.Logger.Noop, []}

  describe "emit/2 with implicit context" do
    test "accepts empty log record" do
      assert :ok == Otel.API.Logs.Logger.emit(@noop_logger)
    end

    test "accepts log record with all fields" do
      log_record = %{
        timestamp: System.system_time(:nanosecond),
        observed_timestamp: System.system_time(:nanosecond),
        severity_number: 9,
        severity_text: "INFO",
        body: Otel.API.Common.AnyValue.string("Hello, world!"),
        attributes: [
          Otel.API.Common.Attribute.new("key", Otel.API.Common.AnyValue.string("value"))
        ],
        event_name: "my.event"
      }

      assert :ok == Otel.API.Logs.Logger.emit(@noop_logger, log_record)
    end

    test "accepts log record with partial fields" do
      assert :ok ==
               Otel.API.Logs.Logger.emit(@noop_logger, %{
                 severity_number: 17,
                 body: Otel.API.Common.AnyValue.string("Error occurred")
               })
    end
  end

  describe "emit/3 with explicit context" do
    test "accepts explicit context" do
      ctx = Otel.API.Ctx.get_current()

      assert :ok ==
               Otel.API.Logs.Logger.emit(@noop_logger, ctx, %{
                 body: Otel.API.Common.AnyValue.string("with context")
               })
    end
  end

  describe "enabled?/2" do
    test "noop returns false" do
      refute Otel.API.Logs.Logger.enabled?(@noop_logger)
    end

    test "accepts opts with severity_number" do
      refute Otel.API.Logs.Logger.enabled?(@noop_logger, severity_number: 9)
    end

    test "accepts opts with event_name" do
      refute Otel.API.Logs.Logger.enabled?(@noop_logger, event_name: "my.event")
    end

    test "accepts opts with severity_number and event_name" do
      refute Otel.API.Logs.Logger.enabled?(@noop_logger,
               severity_number: 9,
               event_name: "my.event"
             )
    end

    test "accepts explicit context" do
      ctx = Otel.API.Ctx.get_current()
      refute Otel.API.Logs.Logger.enabled?(@noop_logger, ctx: ctx)
    end

    test "injects current context when not provided" do
      refute Otel.API.Logs.Logger.enabled?(@noop_logger, severity_number: 9)
    end
  end
end
