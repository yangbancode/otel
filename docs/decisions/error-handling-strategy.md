# Error Handling Strategy

## Question

How does the SDK handle errors without crashing instrumented applications? What patterns ensure the OTel mandate of "never crash the host"?

## Decision

TBD

## Compliance

- `compliance/api-propagators.md` — Extract MUST NOT throw on parse failure
- `compliance/trace-api.md` — Invalid TraceState handling
- `compliance/logs-sdk.md` — OnEmit SHOULD NOT block or throw exceptions
