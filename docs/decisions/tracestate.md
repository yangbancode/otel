# TraceState

## Question

How to implement TraceState (ordered key-value list per W3C Trace Context) in Elixir?

## Decision

### Data Structure

Ordered list of `{key, value}` tuples, wrapped in a struct. Same approach as opentelemetry-erlang's `#tracestate{}` record.

Keys and values are strings conforming to W3C Trace Context spec:
- Key: `[a-z][a-z0-9_\-*/]{0,255}` or multi-tenant `tenant@vendor`
- Value: printable US-ASCII (0x20-0x7E), 1-256 chars, no trailing spaces
- Maximum 32 members

### Operations

Per spec (L284), at minimum:

| Function | Description |
|---|---|
| `new/0,1` | Create empty or from list of pairs |
| `get/2` | Get value for key |
| `put/3` | Add new or update existing key/value (moved to front) |
| `delete/2` | Remove key/value pair |
| `encode/1` | Encode to W3C header string |
| `decode/1` | Decode from W3C header string |

All mutating operations validate input and return unchanged TraceState on invalid input (L294-L295).

### Module: `Otel.API.Trace.TraceState`

Location: `apps/otel_api/lib/otel/api/trace/tracestate.ex`

## Compliance

- [Trace API](../compliance/trace-api.md)
  * TraceState — L284, L291, L292, L293, L294, L295
