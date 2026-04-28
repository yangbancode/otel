# Log

Two paths into OpenTelemetry Logs:

- **Elixir's `:logger` bridge** (most common) — every `Logger.info/2`
  call becomes an OTel `LogRecord`.
- **SDK API** — emit a `LogRecord` directly. For library authors and
  instrumentation that wants full control over the record.

## `:logger` bridge

Attach the handler once at boot — see [Logger Handler](logger-handler.md).

### Plain message

```elixir
require Logger

Logger.info("checkout completed")
```

### Structured (recommended)

Pass metadata as keyword pairs; the bridge maps each non-reserved key
to a LogRecord attribute.

```elixir
Logger.info("checkout completed", user_id: 42, total: 99.95)
```

Map / report form is preserved as a structured body:

```elixir
Logger.info(%{event: "upload", size: 1024})
```

### Severity

Use the standard `:logger` levels — they map to OTel `SeverityNumber`
(`:emergency` → 21, `:alert` → 19, `:critical` → 18, `:error` → 17,
`:warning` → 13, `:notice` → 10, `:info` → 9, `:debug` → 5).

```elixir
Logger.warning("retry exhausted", attempt: 5)
Logger.error("payment provider timeout")
```

### Exceptions

Set `crash_reason` to attach the exception struct + a formatted
stacktrace attribute to the LogRecord.

```elixir
try do
  process_payment()
rescue
  e ->
    Logger.error("payment failed", crash_reason: {e, __STACKTRACE__})
    reraise e, __STACKTRACE__
end
```

## SDK API

```elixir
scope = %Otel.API.InstrumentationScope{name: "my_app", version: "1.0.0"}
logger = Otel.API.Logs.LoggerProvider.get_logger(scope)
```

### String body

```elixir
Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
  body: "checkout completed",
  severity_number: 9,
  severity_text: "info",
  attributes: %{"user.id" => 42}
})
```

### Structured (map) body

```elixir
Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
  body: %{"event" => "upload", "size" => 1024},
  severity_number: 9
})
```

### Raw bytes body

Wrap binary in a `{:bytes, _}` tag so the OTLP encoder serializes it
as `bytes_value` instead of trying UTF-8.

```elixir
Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
  body: {:bytes, <<0xCA, 0xFE, 0xBA, 0xBE>>},
  severity_number: 9
})
```

### With trace context

The current span's IDs flow through automatically when the call site
is inside a `with_span/4` block — no extra wiring needed.
