# SDK Span Creation Flow

## Question

What is the full span creation sequence in the SDK? How do sampling, ID generation, and processor notification fit together?

## Decision

### Flow (per spec L339)

```
1. Determine trace_id
   - Valid parent → use parent's trace_id
   - No valid parent → generate new trace_id (IdGenerator)

2. Query Sampler.should_sample
   - Input: ctx, trace_id, links, name, kind, attributes
   - Output: {decision, sampler_attributes, tracestate}

3. Generate new span_id (IdGenerator)
   - Always generated, even if dropped (for logs/exceptions)

4. Create span based on decision
   - :record_and_sample → is_recording=true, trace_flags=1, insert ETS, notify processors
   - :record_only → is_recording=true, trace_flags=0, insert ETS, notify processors
   - :drop → return non-recording SpanContext
```

### SDK Tracer Implementation

`Otel.SDK.Trace.Tracer.start_span/4` implements this flow by:
1. Reading config from TracerProvider (via provider pid)
2. Calling `Otel.SDK.Trace.SpanCreator.start_span/5` with config

### Module: `Otel.SDK.Trace.SpanCreator`

Location: `apps/otel_sdk/lib/otel/sdk/trace/span_creator.ex`

Pure function module (no GenServer) that orchestrates the creation flow. Same role as opentelemetry-erlang's `otel_span_utils`.

## Compliance

- [Trace SDK](../compliance/trace-sdk.md)
  * Additional Span Interfaces — L242, L249, L251, L255, L260, L266, L283
  * SDK Span Creation — L339
