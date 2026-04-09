# Span Interface & Lifecycle

## Question

How to define the Span interface and manage its lifecycle on BEAM? Behaviour, protocol, or plain functions? Concurrency safety model?

## Decision

TBD

## Compliance

- `compliance/trace-api.md` — Span general + Lifetime + Concurrency (14 items: naming, start time, mutability, no attribute access, must be created via Tracer, timestamps, concurrency)
