# W3C Trace Context Level (Level 2)

## Question

Which version of the W3C Trace Context specification does our
implementation target — Level 1 (REC, 2020) or Level 2
(Candidate Recommendation)?

## Decision

**Level 2.**

OTel Trace API specification makes this choice for us.
`context/api-propagators.md` line 383:

> A W3C Trace Context propagator MUST parse and validate the
> `traceparent` and `tracestate` HTTP headers as specified in
> [W3C Trace Context **Level 2**](https://www.w3.org/TR/trace-context-2/).

This is a `MUST` clause, not a `SHOULD` or an informative note.
OTel-conformant implementations have no discretion on the level.

## Implications

### `Otel.API.Trace.TraceState` key grammar

Level 2 unifies the key grammar into a single production,
whereas Level 1 had separate `simple-key` and `multi-tenant`
forms:

| | Level 1 | Level 2 (target) |
|---|---|---|
| first char | `lcalpha` (simple) or `lcalpha`/`DIGIT` (tenant-id of multi-tenant) | `lcalpha` / `DIGIT` |
| `@` placement | only as tenant/system separator | allowed anywhere in `keychar` |
| grammar | two alternatives | one production |
| max length | 256 | 256 |

Level 2 is strictly more permissive than Level 1. Keys that
Level 1 would reject (`1vendor`, `a@b@c`) Level 2 accepts.

`apps/otel_api/lib/otel/api/trace/tracestate.ex` — `@key_regex`:

```elixir
@key_regex ~r/^[a-z0-9][a-z0-9_\-*\/@]{0,255}$/
```

### Value grammar

Unchanged between Level 1 and Level 2. See W3C §3.3.1.3.2.

### Limits

Unchanged between Level 1 and Level 2:

- 32 list-members (W3C §3.3.1.1)
- 512 bytes header (W3C §3.3.1.5)

### Mutation rules

Unchanged between Level 1 and Level 2. See W3C §3.5.

## Submodule pinning

`references/w3c-trace-context/` is pinned to the `level-2` branch
(commit `82c5ffd`, 2024-03). The branch contains the
Candidate Recommendation content used for implementation reference.

The `level-1` branch remains in the upstream repo for historical
reference but is not the target of our code.

## References

- W3C Trace Context Level 2: `w3c-trace-context/spec/20-http_request_header_format.md`
- OTel mandate: `opentelemetry-specification/specification/context/api-propagators.md#L383`
