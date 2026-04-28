defmodule Otel.API.Logs.Logger.NoopTest do
  use ExUnit.Case, async: true

  # Spec logs/noop.md L33-L35: "MUST NOT validate any argument...
  # MUST NOT return any non-empty error or log any message."

  @logger {Otel.API.Logs.Logger.Noop, []}
  @ctx Otel.API.Ctx.current()

  describe "emit/3 — silently discards every shape of log record" do
    test "minimal record" do
      record = %Otel.API.Logs.LogRecord{body: "test"}

      assert :ok = Otel.API.Logs.Logger.Noop.emit(@logger, @ctx, record)
    end

    test "fully populated record" do
      record = %Otel.API.Logs.LogRecord{
        timestamp: 1_000_000,
        observed_timestamp: 1_000_000,
        severity_number: 9,
        severity_text: "INFO",
        body: %{"nested" => "value"},
        attributes: %{"key" => "val"},
        event_name: "my.event"
      }

      assert :ok = Otel.API.Logs.Logger.Noop.emit(@logger, @ctx, record)
    end
  end

  # Spec logs/noop.md L62: MUST always return false.
  test "enabled?/2 always false, regardless of opts" do
    refute Otel.API.Logs.Logger.Noop.enabled?(@logger, [])
    refute Otel.API.Logs.Logger.Noop.enabled?(@logger, severity_number: 17, event_name: "x")
  end
end
