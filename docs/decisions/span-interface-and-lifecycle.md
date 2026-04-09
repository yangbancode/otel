# Span Interface & Lifecycle

## Question

How to define the Span interface and manage its lifecycle on BEAM? Behaviour, protocol, or plain functions? Concurrency safety model?

## Decision

TBD

## Compliance

- [Trace API](../compliance/trace-api.md)
  * Span — L329, L333, L365, L366, L368, L371, L375
  * Span Operations — Get Context — L457, L460
  * Span Operations — IsRecording — L478, L483, L485
  * Span Lifetime — L715
  * Concurrency Requirements — L842, L845, L848, L851, L853
