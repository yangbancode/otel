# Span Creation

## Question

How does the Trace API create spans? How to determine parent from context, handle root span option, and pass creation attributes?

## Decision

TBD

## Compliance

- `compliance/trace-api.md` — Span Creation (14 items: only via Tracer, not auto-activate, accept name, parent context, attributes at creation, start timestamp, root span, same TraceId, inherit TraceState, must end, links at creation)
