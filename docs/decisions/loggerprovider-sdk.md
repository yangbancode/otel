# LoggerProvider SDK

## Question

How to implement LoggerProvider SDK on BEAM? Provider creation, configuration, Logger creation, shutdown, force-flush, and concurrency?

## Decision

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Logs.LoggerProvider` | `apps/otel_sdk/lib/otel/sdk/logs/logger_provider.ex` | GenServer — owns config, creates loggers |
| `Otel.SDK.Logs.Logger` | `apps/otel_sdk/lib/otel/sdk/logs/logger.ex` | SDK Logger — emit dispatches to processors |

### LoggerProvider

GenServer that mirrors TracerProvider/MeterProvider pattern. Owns resource and processors configuration. Registers as global provider on start.

- `get_logger/2,3,4` — creates `{Otel.SDK.Logs.Logger, config}` with scope and resource
- `shutdown/1,2` — invokes shutdown on all processors, subsequent get_logger returns noop
- `force_flush/1,2` — invokes force_flush on all processors
- Invalid name (nil/empty) returns a working Logger with empty name and logs a warning

### Dynamic Configuration via persistent_term

Processors are stored in `persistent_term` so that config updates propagate to all existing loggers without re-creation. Logger config holds a `processors_key` instead of a snapshot of the processor list. The key is instance-specific (generated via `make_ref()` in `init/1`) to prevent cross-instance collisions when multiple LoggerProviders exist. This satisfies the spec requirement that configuration changes MUST apply to already-returned Loggers (L97).

### SDK Logger

Implements `Otel.API.Logs.Logger` behaviour:

- **`emit/3`** — Builds a complete log record (defaults, trace context extraction, exception attributes) and dispatches to all registered processors via `on_emit/2`.
- **`enabled?/2`** — Returns `true` when at least one processor is registered, `false` otherwise.

### Log Record Construction

On emit, the SDK Logger:

1. Sets `observed_timestamp` to current time if not provided
2. Extracts `trace_id`, `span_id`, `trace_flags` from the resolved Context
3. If `exception` is provided, sets `exception.type`, `exception.message`, and `exception.stacktrace` (when `:stacktrace` is in the log record) attributes per semantic conventions (user attributes take precedence)
4. Attaches `scope` and `resource` from the logger config

## Compliance

- [Logs SDK](../compliance.md)
  * LoggerProvider — L55, L59, L60
  * LoggerProvider Creation — L65
  * Logger Creation — L69, L72, L74, L79, L80, L81
  * Configuration — L92, L97
  * Shutdown — L140, L141, L144, L147, L152
  * ForceFlush — L163, L163, L167, L172
  * Emit a LogRecord (SDK) — L226, L228, L231
  * Enabled (SDK) — L256, L267, L270
  * Concurrency Requirements (SDK) — L654, L657
