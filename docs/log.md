# Log

Two paths into OpenTelemetry Logs:

- **Elixir's `:logger` bridge** (most common) — every `Logger.info/2`
  call becomes an OTel `LogRecord`.
- **SDK API** — emit a `LogRecord` directly. For library authors and
  instrumentation that wants full control over the record.

## Quick start

```elixir
# config/config.exs — attach the handler at boot
config :kernel,
  logger: [
    {:handler, :otel, Otel.LoggerHandler, %{
      config: %{scope_name: "my_app"}
    }}
  ]
```

```elixir
require Logger
Logger.info("checkout completed", user_id: 42)
```

The SDK ships logs to `http://localhost:4318/v1/logs` by default.
See [Configuration](configuration.md) to change endpoint, processor,
or limits.

## `:logger` bridge

The handler converts every `:logger` call into a LogRecord and forwards
to the SDK. See [Logger Handler](logger-handler.md) for the full
attribute mapping.

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

`:logger` levels map to OTel `SeverityNumber`:

| `:logger` | `severity_number` | Use for |
|---|---|---|
| `:emergency` | 21 | system unusable, immediate action required |
| `:alert` | 19 | action required quickly |
| `:critical` | 18 | critical condition |
| `:error` | 17 | runtime error condition |
| `:warning` | 13 | warning condition; operation continues |
| `:notice` | 10 | normal but significant |
| `:info` | 9 | informational |
| `:debug` | 5 | debug detail |

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

### Trace context auto-propagation

When `Logger` fires inside a `with_span/4` block, the LogRecord
automatically carries the active span's `trace_id` / `span_id` — no
extra wiring needed.

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
is inside a `with_span/4` block — same rule as the `:logger` bridge.

## Limits

Defaults: 128 attributes per LogRecord, no string-length truncation.

```elixir
config :otel,
  logs: [
    log_record_limits: %{
      attribute_count_limit: 256,
      attribute_value_length_limit: 1024
    }
  ]
```

See [Configuration](configuration.md) §"Logs pillar" for processor,
batch, and environment-variable knobs.
