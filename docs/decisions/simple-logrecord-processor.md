# Simple LogRecord Processor

## Question

How to implement SimpleLogRecordProcessor on BEAM? Synchronous export on each emit, serialization of export calls?

## Decision

### Module

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Logs.SimpleProcessor` | `apps/otel_sdk/lib/otel/sdk/logs/simple_processor.ex` | GenServer — synchronous export |

### Design

Mirrors `Otel.SDK.Trace.SimpleProcessor` pattern. A GenServer serializes all export calls to ensure the exporter is never called concurrently.

- **`on_emit/2`** — Immediately exports the log record via `GenServer.call`
- **`enabled?/2`** — Always returns `true`
- **`shutdown/1`** — Shuts down the exporter, rejects subsequent emits
- **`force_flush/1`** — No-op (synchronous processor has no buffer)

### Exporter Integration

The processor initializes the exporter via `init/1` and holds its state. Each `on_emit` wraps the log record in a single-element list and calls `export/2`. On shutdown, the exporter's `shutdown/1` is invoked.

## Compliance

- [Logs SDK](../compliance.md)
  * Simple Processor — L521
