# Span Interface & Lifecycle

## Question

How to define the Span interface and manage its lifecycle on BEAM? Behaviour, protocol, or plain functions? Concurrency safety model?

## Decision

### Span as a Behaviour

Define `Otel.API.Trace.Span` as a behaviour. The SDK provides a concrete implementation. The API provides a dispatch module that delegates to the implementation stored in the tracer's `{module, config}` tuple.

Unlike opentelemetry-erlang which stores `span_sdk` in the SpanContext record, we keep SpanContext spec-pure and dispatch through the Span module directly.

### Lifecycle

1. Created via `Tracer.start_span/4` — returns a SpanContext
2. Operations (set_attribute, add_event, set_status, etc.) take a SpanContext
3. `end_span/1,2` marks the span as finished
4. After end, all operations are silently ignored

### Concurrency

All Span operations MUST be safe for concurrent use (L848). On BEAM this is naturally achieved since span data lives in ETS (SDK concern) and operations are message-passing or atomic.

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.API.Trace.Span` | `apps/otel_api/lib/otel/api/trace/span.ex` | Span behaviour + dispatch functions |

## Compliance

- [Trace API](../compliance.md)
  * Span — L329, L333, L365, L366, L368, L371, L375
  * Span Operations — Get Context — L457, L460
  * Span Operations — IsRecording — L478, L483, L485
  * Span Lifetime — L715
  * Concurrency Requirements — L842, L845, L848, L851, L853
