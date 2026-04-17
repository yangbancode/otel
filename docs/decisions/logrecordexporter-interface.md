# LogRecordExporter Interface

> **Note:** Type representations in this document predate [Spec-First Type System](spec-first-type-system.md). `LogRecord` is promoted to a dedicated struct; "list of log record maps" wording below will be revised when that phase PR lands.

## Question

How to define the LogRecordExporter behaviour on BEAM? Export, ForceFlush, Shutdown callbacks, timeout handling, and concurrency requirements?

## Decision

### Module

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Logs.LogRecordExporter` | `apps/otel_sdk/lib/otel/sdk/logs/log_record_exporter.ex` | Behaviour definition |

### Callbacks

| Callback | Description |
|---|---|
| `init(config)` | Initializes the exporter. Returns `{:ok, state}` or `:ignore`. |
| `export(log_records, state)` | Exports a batch of log records. MUST NOT block indefinitely. |
| `force_flush(state)` | Forces the exporter to flush buffered data. |
| `shutdown(state)` | Shuts down the exporter. After shutdown, export calls SHOULD return failure. |

### Design

Mirrors `Otel.SDK.Trace.SpanExporter` and `Otel.SDK.Metrics.MetricExporter` patterns. Export receives a list of log record maps (ReadableLogRecord) containing all fields: body, severity, attributes, trace context, scope, resource, timestamps, etc.

Export is never called concurrently — the processor serializes calls.

## Compliance

- [Logs SDK](../compliance.md)
  * LogRecordExporter — L559, L563
  * Export — L582, L586
  * Exporter ForceFlush — L620, L622, L627
  * Exporter Shutdown — L637, L638, L640
  * Concurrency Requirements (SDK) — L659
