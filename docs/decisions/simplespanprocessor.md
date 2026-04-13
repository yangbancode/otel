# SimpleSpanProcessor

## Question

How to implement SimpleSpanProcessor on BEAM? How to synchronize export calls?

## Decision

### GenServer

SimpleSpanProcessor is a GenServer that serializes export calls. Each ended span is sent to the exporter immediately via GenServer.call.

### Callbacks

| Callback | Behaviour |
|---|---|
| `on_start(ctx, span, config)` | No-op, returns span unchanged |
| `on_end(span, config)` | Sends span to GenServer for synchronous export |
| `shutdown(config)` | Calls exporter shutdown |
| `force_flush(config)` | No-op (simple processor exports immediately) |

### Export serialization

The GenServer ensures export calls are never concurrent (L1076). Each `on_end` sends a `{:export, span}` call to the GenServer, which calls the exporter synchronously.

Unsampled spans (trace_flags sampled bit = 0) are dropped without calling the exporter.

### Module: `Otel.SDK.Trace.SimpleProcessor`

Location: `apps/otel_sdk/lib/otel/sdk/trace/simple_processor.ex`

## Compliance

- [Trace SDK](../compliance.md)
  * Built-in Span Processors — L1066
  * Built-in Span Processors — Simple Processor — L1076
