# Batch LogRecord Processor

## Question

How to implement BatchLogRecordProcessor on BEAM? Asynchronous batching, queue management, scheduled export, and GenServer design?

## Decision

### Module

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Logs.BatchProcessor` | `apps/otel_sdk/lib/otel/sdk/logs/batch_processor.ex` | GenServer — async batching |

### Configuration

| Option | Env Var | Default | Description |
|---|---|---|---|
| `max_queue_size` | `OTEL_BLRP_MAX_QUEUE_SIZE` | 2048 | Max records in queue |
| `scheduled_delay_ms` | `OTEL_BLRP_SCHEDULE_DELAY` | 1000 | Timer interval |
| `export_timeout_ms` | `OTEL_BLRP_EXPORT_TIMEOUT` | 30000 | Export timeout |
| `max_export_batch_size` | `OTEL_BLRP_MAX_EXPORT_BATCH_SIZE` | 512 | Max batch size |

### Design

Mirrors `Otel.SDK.Trace.BatchProcessor` pattern:

- **`on_emit/2`** — Adds to queue via `GenServer.cast` (non-blocking). Triggers export if batch size threshold reached.
- **Timer** — Periodic `handle_info(:export_timer)` flushes the queue.
- **Queue full** — Records beyond `max_queue_size` are silently dropped.
- **`force_flush/1`** — Synchronous export of all pending records.
- **`shutdown/1`** — Exports remaining records, shuts down exporter.

Export calls are serialized via the GenServer — the exporter is never called concurrently.

## Compliance

- [Logs SDK](../compliance.md)
  * Batching Processor — L534
