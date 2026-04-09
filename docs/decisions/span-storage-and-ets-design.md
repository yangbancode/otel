# Span Storage & ETS Design

## Question

How to store mutable span data during its lifecycle on BEAM? ETS table design, process-per-span alternative, and concurrency model?

## Decision

TBD

## Compliance

- `compliance/trace-sdk.md` — Concurrency requirements (4 items: TracerProvider, Sampler, SpanProcessor, SpanExporter thread-safety)
