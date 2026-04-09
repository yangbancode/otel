# SDK Internal Logging Strategy

## Question

How does the SDK emit its own diagnostic messages (invalid name warnings, attribute truncation, duplicate instruments)? How to leverage Erlang's `:logger` for OTel-internal logging?

## Decision

TBD

## Compliance

Crosscutting — all "SHOULD log/warn" items across compliance files:
- `compliance/trace-sdk.md` — Span Limits discard message
- `compliance/metrics-sdk.md` — invalid name, duplicate instrument warnings
- `compliance/logs-sdk.md` — invalid name warning
