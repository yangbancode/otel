defmodule Otel.API.Logs.LoggerTest do
  use ExUnit.Case, async: true

  # Verifies the facade dispatches to the registered Logger
  # module. Behaviour of the Noop fallback itself is covered in
  # `Otel.API.Logs.Logger.NoopTest`.

  @logger {Otel.API.Logs.Logger.Noop, []}

  describe "emit/1,2,3 — dispatches to the Logger module" do
    test "with implicit context, all arities" do
      record = %Otel.API.Logs.LogRecord{body: "msg"}

      assert :ok = Otel.API.Logs.Logger.emit(@logger)
      assert :ok = Otel.API.Logs.Logger.emit(@logger, record)
    end

    test "with explicit context" do
      ctx = Otel.Ctx.current()
      record = %Otel.API.Logs.LogRecord{body: "with context"}

      assert :ok = Otel.API.Logs.Logger.emit(@logger, ctx, record)
    end

    test "forwards a fully-populated record" do
      now = System.system_time(:nanosecond)

      record = %Otel.API.Logs.LogRecord{
        timestamp: now,
        observed_timestamp: now,
        severity_number: 9,
        severity_text: "INFO",
        body: "Hello, world!",
        attributes: %{"key" => "value"},
        event_name: "my.event"
      }

      assert :ok = Otel.API.Logs.Logger.emit(@logger, record)
    end
  end

  # Spec logs/api.md L133-L154: Enabled accepts severity_number,
  # event_name, and ctx in opts. The Noop returns false regardless;
  # this test asserts the facade forwards each opt shape to dispatch.
  test "enabled?/2 dispatches with each documented opt shape" do
    refute Otel.API.Logs.Logger.enabled?(@logger)
    refute Otel.API.Logs.Logger.enabled?(@logger, severity_number: 9)
    refute Otel.API.Logs.Logger.enabled?(@logger, event_name: "my.event")
    refute Otel.API.Logs.Logger.enabled?(@logger, severity_number: 9, event_name: "my.event")
    refute Otel.API.Logs.Logger.enabled?(@logger, ctx: Otel.Ctx.current())
  end
end
