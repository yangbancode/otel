# Span Operations

## Question

How to implement SDK-level span operations (set_attribute, add_event, set_status, update_name, end_span, record_exception) that mutate ETS-stored spans and enforce limits?

## Decision

### API Dispatch via Global Registration

The API module `Otel.API.Trace.Span` dispatches to a registered SDK module via `persistent_term`, following the same pattern as `TracerProvider`.

- `Otel.API.Trace.Span.set_span_module/1` / `get_span_module/0` — register/lookup
- SDK registers `Otel.SDK.Trace.SpanOperations` in `Otel.SDK.Application.start/2`
- Without SDK, all operations are no-ops (return `:ok`)

### SDK Module: `Otel.SDK.Trace.SpanOperations`

Location: `apps/otel_sdk/lib/otel/sdk/trace/span_ops.ex`

All operations follow the pattern:
1. `SpanStorage.get(span_id)` — if nil (ended or dropped), silently return `:ok`
2. Apply operation with limit enforcement
3. `SpanStorage.insert(updated_span)` — write back

### Span Struct Additions

Added `span_limits` and `processors` fields to `Otel.SDK.Trace.Span` struct. These are stored per-span at creation time so that operations and `end_span` can access them without requiring the TracerProvider.

### Operations

| Operation | Behavior |
|---|---|
| `set_attribute` | Overwrite if key exists; add if under count limit; truncate string values |
| `set_attributes` | Batch version of `set_attribute` |
| `add_event` | Check `event_count_limit`; enforce `attribute_per_event_limit` on event attrs |
| `add_link` | Check `link_count_limit`; enforce `attribute_per_link_limit` on link attrs |
| `set_status` | Priority: Ok > Error > Unset. Ok is final. Unset is ignored |
| `update_name` | Simple replacement |
| `end_span` | `SpanStorage.take` (atomic remove), set `end_time`/`is_recording=false`, call `on_end` on all processors |
| `record_exception` | Creates `"exception"` event with `exception.type`, `exception.message`, `exception.stacktrace` |
| `recording?` | Returns `true` if span exists in ETS |

### Limit Enforcement

- `attribute_count_limit` — new keys rejected when at limit; overwrites always allowed
- `attribute_value_length_limit` — string values truncated; non-string values unaffected
- `event_count_limit` — events silently dropped when at limit
- `link_count_limit` — links silently dropped when at limit
- `attribute_per_event_limit` — event attributes truncated at creation
- `attribute_per_link_limit` — link attributes truncated at creation

### Design Differences from opentelemetry-erlang

- Erlang uses `ets:lookup_element`/`ets:update_element` for field-level updates; we use full get/insert for simplicity
- Erlang stores `is_recording` in SpanContext; we keep SpanContext spec-pure and check ETS presence instead
- Erlang stores processors as a closure in `span_sdk` tuple; we store processors list in the Span struct

## Compliance

- [Trace API](../compliance/trace-api.md)
  * Span Operations — Set Attributes — L497, L499, L510
  * Span Operations — Add Events — L522, L533, L544
  * Span Operations — Add Link — L562
  * Span Operations — Set Status — L574, L594, L599, L603, L619
  * Span Operations — UpdateName — L633
  * Span Operations — End — L652, L659, L662, L665, L666, L673, L677
  * Span Operations — Record Exception — L686, L693, L695, L697, L699
  * Span Operations — IsRecording — L478, L483, L485
  * Span Lifetime — L715
- [Trace SDK](../compliance/trace-sdk.md)
  * Span Processor — OnEnd — L1008
