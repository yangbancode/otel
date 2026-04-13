# W3C TraceContext Propagator

## Question

How to implement W3C TraceContext propagation (traceparent + tracestate headers)?

## Decision

### Module: `Otel.API.Propagator.TraceContext`

Location: `apps/otel_api/lib/otel/api/propagator/trace_context.ex`

Implements `Otel.API.Propagator.TextMap` behaviour for W3C Trace Context Level 2.

### Headers

| Header | Format | Example |
|---|---|---|
| `traceparent` | `VERSION-TRACEID-SPANID-TRACEFLAGS` | `00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01` |
| `tracestate` | `key=value,key=value` | `vendor=value` |

### Inject

1. Get SpanContext from context
2. If invalid (zero trace_id or span_id), skip
3. Encode traceparent: `00-{trace_id_hex}-{span_id_hex}-{flags_hex}`
4. If tracestate is non-empty, encode and set header

### Extract

1. Read traceparent header from carrier
2. Validate: version >= "00" and != "ff", non-zero IDs, valid hex
3. Parse trace_id, span_id, trace_flags
4. Read and decode tracestate header (if present)
5. Create SpanContext with `is_remote: true`
6. Return new context with extracted span
7. On any parse failure, return original context (no exception)

### Parsing

Uses Erlang binary pattern matching for efficient parsing:

```elixir
<<version::binary-size(2), "-", trace_id_hex::binary-size(32), "-",
  span_id_hex::binary-size(16), "-", flags_hex::binary-size(2), _rest::binary>>
```

The `_rest::binary` allows forward compatibility with future versions that may append additional fields.

## Compliance

- [API Propagators](../compliance/api-propagators.md)
  * W3C Trace Context Requirements — L383, L383, L383
