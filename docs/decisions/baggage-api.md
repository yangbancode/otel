# Baggage API

## Question

How to implement the Baggage API on BEAM? Immutable map in Context, get/set/remove/clear operations?

## Decision

### Module: `Otel.API.Baggage`

Location: `apps/otel_api/lib/otel/api/baggage.ex`

Fully functional without SDK — all operations are pure API.

### Data Structure

Baggage is stored as an immutable Elixir map:

```elixir
%{name => {value, metadata}}
```

- `name` — case-sensitive UTF-8 string
- `value` — case-sensitive UTF-8 string
- `metadata` — opaque string (W3C baggage properties)

Follows opentelemetry-erlang's `#{key => {value, metadata}}` pattern.

### Operations

| Function | Description |
|---|---|
| `get_value(baggage, name)` | Returns value or nil |
| `get_all(baggage)` | Returns all entries |
| `set_value(baggage, name, value, metadata)` | Returns new Baggage with entry added/replaced |
| `remove_value(baggage, name)` | Returns new Baggage without entry |

### Context Interaction

| Function | Description |
|---|---|
| `get_baggage(ctx)` | Extract from explicit context |
| `set_baggage(ctx, baggage)` | Insert into explicit context |
| `get_baggage()` | Get from implicit (process) context |
| `set_baggage(baggage)` | Set in implicit (process) context |
| `clear(ctx)` / `clear()` | Remove all entries |

Context key: `:"__otel.baggage__"` (hidden from users).

### Conflict Resolution

`set_value` with existing name replaces the old value (Map.put semantics). On propagation extract, `Map.merge(existing, remote)` ensures remote values take precedence.

## Compliance

- [Baggage](../compliance/baggage.md)
  * Overview — L38, L43, L53, L57, L79, L84
  * Operations — L92, L102, L108, L128
  * Context Interaction — L144, L149, L154, L166
  * Clear Baggage — L172
  * Conflict Resolution — L207
