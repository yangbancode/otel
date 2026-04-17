# SpanContext

## Question

How to represent SpanContext in Elixir? Binary format for trace_id/span_id, hex conversion, and internal storage? How to implement IsValid and IsRemote?

## Decision

### Struct

Elixir struct holding the spec-defined fields:

```elixir
defstruct [
  :trace_id,
  :span_id,
  trace_flags: 0,
  tracestate: %TraceState{},
  is_remote: false
]
```

Only spec-defined fields are stored. `IsValid` is a function that computes from trace_id and span_id, not a cached field. `IsRecording` belongs to the Span interface (L478), not SpanContext.

### ID Representation

`trace_id` and `span_id` are opaque structs from the Spec-First Type System — `Otel.API.Trace.TraceId.t()` (16 bytes internally) and `Otel.API.Trace.SpanId.t()` (8 bytes internally). Hex and raw-bytes conversions are exposed via module functions rather than cached on the struct.

| Field | Type | Size |
|---|---|---|
| `trace_id` | `Otel.API.Trace.TraceId.t()` | 16 bytes |
| `span_id` | `Otel.API.Trace.SpanId.t()` | 8 bytes |
| `trace_flags` | `non_neg_integer()` | 8 bits |

All-zero IDs represent invalid/empty values; validity is tested through `TraceId.valid?/1` and `SpanId.valid?/1`.

### Functions

| Function | Description |
|---|---|
| `new/4` | Create from `TraceId.t()`, `SpanId.t()`, trace_flags, tracestate |
| `valid?/1` | `TraceId.valid?/1` AND `SpanId.valid?/1` |
| `remote?/1` | Returns `is_remote` field |
| `sampled?/1` | Lowest bit of trace_flags is 1 |
| `trace_id_hex/1` | Delegates to `TraceId.to_hex/1` (32-char lowercase hex) |
| `span_id_hex/1` | Delegates to `SpanId.to_hex/1` (16-char lowercase hex) |
| `trace_id_bytes/1` | Delegates to `TraceId.to_bytes/1` (16-byte binary) |
| `span_id_bytes/1` | Delegates to `SpanId.to_bytes/1` (8-byte binary) |

### Module: `Otel.API.Trace.SpanContext`

Location: `apps/otel_api/lib/otel/api/trace/span_context.ex`

## Compliance

- [Trace API](../compliance.md)
  * SpanContext — L252, L253, L253
  * Retrieving the TraceId and SpanId — L258, L261, L262, L263, L264, L266
  * IsValid — L270
  * IsRemote — L275, L278, L278
