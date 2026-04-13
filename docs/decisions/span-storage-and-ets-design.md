# Span Storage & ETS Design

## Question

How to store mutable span data during its lifecycle on BEAM? ETS table design, process-per-span alternative, and concurrency model?

## Decision

### ETS Table

A single named ETS table stores all active spans, same as opentelemetry-erlang. The table is `public` with `write_concurrency: true` and `read_concurrency: true` for lock-free concurrent access from multiple processes.

Key: `span_id` (64-bit integer) — O(1) lookup.

### Span Record

Internal span struct stored in ETS with all mutable fields:

| Field | Description |
|---|---|
| `trace_id` | 128-bit trace identifier |
| `span_id` | 64-bit span identifier (ETS key) |
| `tracestate` | W3C TraceState |
| `parent_span_id` | parent span's ID |
| `parent_span_is_remote` | whether parent is from remote process |
| `name` | span name |
| `kind` | SpanKind |
| `start_time` | start timestamp |
| `end_time` | end timestamp |
| `attributes` | mutable attribute map |
| `events` | list of events |
| `links` | list of links |
| `status` | span status |
| `trace_flags` | 8-bit trace flags |
| `is_recording` | recording state |
| `instrumentation_scope` | scope from tracer |

### Lifecycle

1. `start_span` — create span record, insert into ETS
2. Operations (set_attribute, etc.) — update ETS record in-place
3. `end_span` — `ets:take` removes from ETS, passes to processors

### Concurrency

Spans are typically modified only by the process that created them (through the current context). ETS `write_concurrency` handles the rare case of cross-process access. No additional locking needed.

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Trace.Span` | `apps/otel_sdk/lib/otel/sdk/trace/span.ex` | Internal span struct |
| `Otel.SDK.Trace.SpanStorage` | `apps/otel_sdk/lib/otel/sdk/trace/span_storage.ex` | ETS table GenServer + span operations |

## Compliance

- [Trace SDK](../compliance.md)
  * Concurrency requirements — L1281, L1284, L1287, L1289
