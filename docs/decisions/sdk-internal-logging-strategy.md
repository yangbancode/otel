# SDK Internal Logging Strategy

## Question

How does the SDK emit its own diagnostic messages (invalid name warnings, attribute truncation, duplicate instruments)? How to leverage Erlang's `:logger` for OTel-internal logging?

## Decision

TBD

## Compliance

Crosscutting — "SHOULD log/warn" items across compliance files:
- `compliance/trace-sdk.md` — Span Limits
- `compliance/metrics-sdk.md` — Meter Creation, Duplicate Instrument Registration, Name Conflict
- `compliance/logs-sdk.md` — Logger Creation
