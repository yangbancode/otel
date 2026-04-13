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

Per spec (L284), four separate operations plus encode/decode:

| Function | Description |
|---|---|
| `new/0,1` | Create empty or from list of pairs |
| `get/2` | Get value for key |
| `add/3` | Add new key/value pair to front |
| `update/3` | Update existing key's value and move to front |
| `delete/2` | Remove key/value pair |
| `encode/1` | Encode to W3C header string |
| `decode/1` | Decode from W3C header string |

`add/3` and `update/3` are separate per spec — add prepends without deduplication, update only works on existing keys. Both validate input and return unchanged TraceState on invalid input (L294-L295).

`decode/1` rejects the entire header if any entry is invalid or if the number of members exceeds 32.

### Module: `Otel.API.Trace.TraceState`

Location: `apps/otel_api/lib/otel/api/trace/tracestate.ex`

## Compliance

- [Trace API](../compliance.md)
  * TraceState — L284, L291, L292, L293, L294, L295
