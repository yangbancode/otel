# SpanContext

## Question

How to represent SpanContext in Elixir? Binary format for trace_id/span_id, hex conversion, and internal storage? How to implement IsValid and IsRemote?

## Decision

### Struct

Elixir struct matching the opentelemetry-erlang `#span_ctx{}` record:

```elixir
defstruct [
  :trace_id,
  :span_id,
  trace_flags: 0,
  tracestate: %TraceState{},
  is_remote: false,
  is_recording: false
]
```

`IsValid` is a function that computes from trace_id and span_id, not a cached field. `is_recording` is an implementation field (same as opentelemetry-erlang) needed to distinguish recording vs non-recording spans in the Noop tracer and SDK.

### ID Representation

Same as opentelemetry-erlang: trace_id is a 128-bit integer, span_id is a 64-bit integer. Stored as non-negative integers, not binaries. Hex conversion is done via functions, not cached in the struct.

| Field | Type | Size |
|---|---|---|
| `trace_id` | `non_neg_integer()` | 128 bits |
| `span_id` | `non_neg_integer()` | 64 bits |
| `trace_flags` | `non_neg_integer()` | 8 bits |

Zero values (0) represent invalid/empty IDs.

### Functions

| Function | Description |
|---|---|
| `new/4` | Create from trace_id, span_id, trace_flags, tracestate |
| `valid?/1` | Non-zero trace_id AND non-zero span_id |
| `remote?/1` | Returns `is_remote` field |
| `sampled?/1` | Lowest bit of trace_flags is 1 |
| `trace_id_hex/1` | 32-char lowercase hex string |
| `span_id_hex/1` | 16-char lowercase hex string |
| `trace_id_bytes/1` | 16-byte binary |
| `span_id_bytes/1` | 8-byte binary |

### Module: `Otel.API.Trace.SpanContext`

Location: `apps/otel_api/lib/otel/api/trace/span_context.ex`

## Compliance

- [Trace API](../compliance/trace-api.md)
  * SpanContext — L252, L253, L253
  * Retrieving the TraceId and SpanId — L258, L261, L262, L263, L264, L266
  * IsValid — L270
  * IsRemote — L275, L278, L278
