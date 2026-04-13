# BatchSpanProcessor

## Question

How to implement BatchSpanProcessor on BEAM? GenServer state machine, queue design, flush scheduling?

## Decision

### GenServer with timer

GenServer that accumulates spans in an in-memory queue and exports
them in batches. Export is triggered by:

1. Timer (`scheduled_delay_ms`) expires
2. Queue reaches `max_export_batch_size`
3. `force_flush` is called

### Configurable parameters (per spec L1106-1118)

| Parameter | Default | Description |
|---|---|---|
| `exporter` | required | `{module, opts}` |
| `max_queue_size` | 2048 | Max spans in queue, excess dropped |
| `scheduled_delay_ms` | 5000 | Timer interval between exports |
| `export_timeout_ms` | 30000 | Export call timeout |
| `max_export_batch_size` | 512 | Max spans per export call |

### Export serialization

GenServer serializes export calls (L1089). While exporting, new
spans continue to queue. If queue overflows during export, spans
are dropped.

### Module: `Otel.SDK.Trace.BatchProcessor`

Location: `apps/otel_sdk/lib/otel/sdk/trace/batch_processor.ex`

## Compliance

- [Trace SDK](../compliance.md)
  * Built-in Span Processors — L1066
  * Built-in Span Processors — Batching Processor — L1089, L1092
