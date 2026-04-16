# LogRecordProcessor Interface

## Question

How to define the LogRecordProcessor behaviour on BEAM? OnEmit, Enabled, Shutdown, ForceFlush callbacks and ReadableLogRecord/ReadWriteLogRecord interfaces?

## Decision

### Module

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Logs.LogRecordProcessor` | `apps/otel_sdk/lib/otel/sdk/logs/log_record_processor.ex` | Behaviour definition |

### Callbacks

| Callback | Description |
|---|---|
| `on_emit(log_record, config)` | Called when a log record is emitted. Receives a ReadWriteLogRecord (mutable map). |
| `enabled?(opts, config)` | Returns whether the processor is interested in log records matching the given parameters. |
| `shutdown(config)` | Shuts down the processor. MUST include effects of force_flush. |
| `force_flush(config)` | Forces export of all pending log records. |

### ReadWriteLogRecord

Log records are plain Elixir maps containing all fields from the API plus SDK-added fields: `trace_id`, `span_id`, `trace_flags`, `scope`, `resource`, `observed_timestamp`, `dropped_attributes_count`. Processors MAY modify any field. Mutations are visible to subsequent processors in the chain.

### Enabled Integration

`Otel.SDK.Logs.Logger.enabled?/2` checks processor-level `enabled?/2`:
- Returns `false` when no processors are registered
- Returns `false` when all processors implement `enabled?/2` and each returns `false`
- Otherwise returns `true`

## Compliance

- [Logs SDK](../compliance.md)
  * ReadableLogRecord — L279, L281, L285, L289
  * ReadWriteLogRecord — L302
  * LogRecordProcessor — L363, L365
  * OnEmit — L397, L409
  * Enabled (Processor) — L439
  * Processor Shutdown — L462, L463, L466, L469, L471
  * Processor ForceFlush — L480, L484, L486, L487, L492, L495, L500
  * Built-in Processors — L507, L510
