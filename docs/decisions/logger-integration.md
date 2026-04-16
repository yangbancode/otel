# :logger Integration

## Question

How to bridge Erlang's `:logger` with the OTel Logs SDK? Custom handler, level mapping, metadata extraction, context correlation?

## Decision

### Module

| Module | Location | App | Description |
|---|---|---|---|
| `Otel.Logger.Handler` | `apps/otel_logger_handler/lib/otel/logger/handler.ex` | `otel_logger_handler` | `:logger` handler bridge |

### Architecture

The handler is a separate OTP app (`otel_logger_handler`) that depends only on `otel_api`. It converts `:logger` events into OTel LogRecords and emits them via `Otel.API.Logs.Logger.emit/3`. When an SDK is installed, records flow through the SDK pipeline (processors → exporters). Without an SDK, all emits are no-ops.

Batching and export are handled by the SDK's processor pipeline, not by this handler.

### :logger Handler Callbacks

| Callback | Description |
|---|---|
| `adding_handler/1` | Uses pre-configured `otel_logger` if present; otherwise obtains one via `LoggerProvider.get_logger` |
| `removing_handler/1` | No-op cleanup |
| `log/2` | Converts log event → OTel log_record → `Logger.emit` |
| `changing_config/3` | Accepts new config |
| `filter_config/1` | Returns config unchanged |

### Severity Mapping

| Erlang Level | OTel Severity Number | OTel Severity Text |
|---|---|---|
| `:emergency` | 21 | FATAL |
| `:alert` | 18 | ERROR3 |
| `:critical` | 17 | ERROR |
| `:error` | 17 | ERROR |
| `:warning` | 13 | WARN |
| `:notice` | 12 | INFO4 |
| `:info` | 9 | INFO |
| `:debug` | 5 | DEBUG |

### Metadata → Attributes

| `:logger` meta | OTel attribute |
|---|---|
| `mfa: {M, F, A}` | `code.namespace`, `code.function` |
| `file` | `code.filepath` |
| `line` | `code.lineno` |
| `pid` | `process.pid` |
| `domain` | `log.domain` |

### Trace Context Correlation

The handler reads the current process Context via `Otel.API.Ctx.get_current()` and passes it to `Logger.emit/3`. The SDK Logger extracts `trace_id`/`span_id` from the active span, automatically correlating logs with traces.

### Usage

```elixir
:logger.add_handler(:otel, Otel.Logger.Handler, %{
  config: %{scope_name: "my_app", scope_version: "1.0.0"}
})
```

## Compliance

No direct spec compliance items — `:logger` integration is BEAM-specific and not part of the OTel specification.
