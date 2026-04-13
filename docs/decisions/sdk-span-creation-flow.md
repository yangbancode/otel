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
1. Using pre-cached config from tracer tuple (sampler, id_generator, span_limits, scope)
2. Calling `Otel.SDK.Trace.SpanCreator.start_span/6` with config
3. Applying SpanLimits (attribute count/value length, link count)
4. Running on_start processors, storing recording span in ETS

### Module: `Otel.SDK.Trace.SpanCreator`

Location: `apps/otel_sdk/lib/otel/sdk/trace/span_creator.ex`

Pure function module (no GenServer) that orchestrates the creation flow. Same role as opentelemetry-erlang's `otel_span_utils`.

### Pending for next decisions

All items have been addressed:

- ~~**Processor on_start/on_end notification** — SpanProcessor Interface decision~~ ✅ Done
- ~~**SpanStorage span operations** (set_attribute, add_event, set_status, update_name, end_span) — Span Operations decision~~ ✅ Done
- ~~**event_count_limit / attribute_per_event_limit / attribute_per_link_limit enforcement** — Span Operations decision~~ ✅ Done
- ~~**Link internal attribute limit** (AttributePerLinkCountLimit) — Span Operations decision~~ ✅ Done

## Compliance

- [Trace SDK](../compliance.md)
  * Additional Span Interfaces — L242, L249, L251, L255, L260, L266, L283
  * SDK Span Creation — L339
