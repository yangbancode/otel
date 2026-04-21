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

`add/3` and `update/3` are separate per spec:

- `add/3` prepends new entries. Per W3C §3.5 it rejects duplicate
  keys ("Adding a key/value pair MUST NOT result in the same key
  being present multiple times"), and per W3C §3.3.1.1 it drops
  the right-most entry when already at 32 members.
- `update/3` moves the modified key to the beginning (W3C §3.5).
  Falls through to `add/3` when the key is absent, inheriting the
  32-member cap.

Both return the TraceState unchanged on invalid key/value per
OTel api.md L294-L295.

`decode/1` rejects the entire header if any entry is invalid or if the number of members exceeds 32.

### Module: `Otel.API.Trace.TraceState`

Location: `apps/otel_api/lib/otel/api/trace/tracestate.ex`

## Compliance

- [Trace API](../compliance.md)
  * TraceState — L284, L291, L292, L293, L294, L295
