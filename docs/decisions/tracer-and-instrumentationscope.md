# Tracer & InstrumentationScope

## Question

How to represent Tracer and InstrumentationScope on BEAM? Lightweight struct or process-backed?

## Decision

TBD

## Compliance

- `compliance/trace-api.md` — Tracer (2 items: create span, report if enabled)
- `compliance/trace-sdk.md` — TracerProvider Tracer Creation (3 items: only through provider, implement get-tracer, InstrumentationScope stored)
