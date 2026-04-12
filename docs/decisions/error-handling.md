# Error Handling

## Question

How to ensure OTel SDK never crashes the host application? Where to place error boundaries, and how to handle invalid inputs?

## Decision

TBD — to be decided after all phases are complete, when the full call graph is known.

### Planned approach

1. **Minimum top-level try/catch** at user-facing entry points (start_span, with_span) to catch all downstream errors and return noop
2. **API catch-all clauses** on all public Span/Trace functions for invalid input defense
3. **Remove redundant inner try/catch** that are already covered by top-level boundary
4. **Log suppressed errors** per Logging Convention with appropriate domain

### References

- [OTel error-handling spec](../references/opentelemetry-specification/v1.55.0/error-handling.md)
- [Logging Convention](logging-convention.md)
- opentelemetry-erlang patterns: guard + catch-all (API), try/catch (init), let-it-crash (runtime)

## Compliance
