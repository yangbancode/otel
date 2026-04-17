# Logs API

> **Note:** Type representations in this document predate [Spec-First Type System](spec-first-type-system.md). `LogRecord` and `SeverityNumber` are still native-typed; they will be promoted to dedicated structs when the Logs phase PR lands.

## Question

How to implement LoggerProvider, Logger, Emit LogRecord, and Enabled API on BEAM? How to ensure API works without SDK?

## Decision

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.API.Logs.LoggerProvider` | `apps/otel_api/lib/otel/api/logs/logger_provider.ex` | Global provider registration, Logger caching |
| `Otel.API.Logs.Logger` | `apps/otel_api/lib/otel/api/logs/logger.ex` | Logger behaviour and dispatch |
| `Otel.API.Logs.Logger.Noop` | `apps/otel_api/lib/otel/api/logs/logger/noop.ex` | No-op implementation |

### LoggerProvider

Global registration via `persistent_term`, matching TracerProvider and MeterProvider pattern. `get_logger/4` accepts `name`, `version`, `schema_url`, `attributes` — all but `name` optional. Loggers are cached by `{name, version, schema_url}`.

Invalid name (nil or empty) returns a working Logger and logs a warning.

### Logger

Represented as `{module, config}` tuple. Two operations:

- **`emit/2,3`** — Emits a LogRecord. Accepts a map with optional fields: `timestamp`, `observed_timestamp`, `severity_number`, `severity_text`, `body`, `attributes`, `event_name`, `exception`. Context is either implicit (current) or explicit (3-arity).
- **`enabled?/2`** — Returns whether the logger is enabled. Accepts opts with optional `severity_number`, `event_name`, and `ctx`. Injects current context when not provided.

### Noop

`emit/3` returns `:ok`, `enabled?/2` returns `false`. Used when no SDK is installed.

## Compliance

- [Logs API](../compliance.md)
  * LoggerProvider — L59, L64
  * Get a Logger — L70, L85, L88, L92
  * Logger — L103, L107
  * Emit a LogRecord — L117, L118, L119, L122, L123, L124, L125, L126, L127
  * Enabled — L135, L140, L143, L144, L145, L147, L152
  * Optional and Required Parameters — L161, L164
  * Concurrency Requirements — L172, L175
