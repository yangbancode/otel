# SpanProcessor Interface

## Question

How to define the SpanProcessor behaviour on BEAM? OnStart, OnEnd, Shutdown, ForceFlush callback signatures?

## Decision

### Behaviour

Same pattern as opentelemetry-erlang's `otel_span_processor`:

| Callback | Parameters | Return |
|---|---|---|
| `on_start(ctx, span, config)` | context, read/write span, processor config | span |
| `on_end(span, config)` | readable span | `:ok \| :dropped \| {:error, term()}` |
| `shutdown(config)` | processor config | `:ok \| {:error, term()}` |
| `force_flush(config)` | processor config | `:ok \| {:error, term()}` |

`on_start` and `on_end` are called synchronously — they MUST NOT block or throw.

### Integration with TracerProvider

TracerProvider's `shutdown/1` and `force_flush/1` already cascade to all processors via `invoke_all_processors/2`. SpanProcessor registration happens through TracerProvider config `processors: [{module, config}]`.

### Integration with SDK Tracer

SDK Tracer calls `on_start` after span creation and `on_end` after span end. This is added to the existing `Otel.SDK.Trace.Tracer.start_span/4`.

### Module: `Otel.SDK.Trace.SpanProcessor`

Location: `apps/otel_sdk/lib/otel/sdk/trace/span_processor.ex`

## Compliance

- [Trace SDK](../compliance.md)
  * Span Processor — Interface Definition — L952, L959
  * Span Processor — OnStart — L973
  * Span Processor — OnEnd — L1008
  * Span Processor — Shutdown — L1024, L1026, L1028, L1031, L1033
  * Span Processor — ForceFlush — L1041, L1044, L1047, L1052, L1055, L1059
  * Built-in Span Processors — L1066
