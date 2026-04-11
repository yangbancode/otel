# SDK Span Creation Flow

## Question

What is the full span creation sequence in the SDK? How do sampling, ID generation, and processor notification fit together?

## Decision

### Flow (per spec L339)

```
1. Determine trace_id and generate span_id
   - Valid parent → use parent's trace_id, generate new span_id
   - No valid parent → generate new trace_id + span_id (IdGenerator)
   - span_id is always generated, even if dropped (for logs/exceptions)
   Note: spec says "act as if" this order — erlang also generates
   both IDs together before sampling for efficiency.

2. Query Sampler.should_sample
   - Input: ctx, trace_id, links, name, kind, attributes
   - Output: {decision, sampler_attributes, tracestate}

3. Create span based on decision
   - :record_and_sample → is_recording=true, trace_flags=1, insert ETS
   - :record_only → is_recording=true, trace_flags=0, insert ETS
   - :drop → return non-recording SpanContext (nil span)
   Processor on_start notification will be added in SpanProcessor decision.
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
