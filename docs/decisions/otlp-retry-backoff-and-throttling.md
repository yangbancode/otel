# OTLP Retry, Backoff & Throttling

## Question

How to implement shared retry strategy for OTLP exporters? Exponential backoff with jitter, RetryInfo handling, status code mapping?

## Decision

TBD

## Compliance

- `compliance/otlp-protocol.md` — Failures (gRPC), OTLP/gRPC Throttling, Failures (HTTP), OTLP/HTTP Throttling, All Other Responses, OTLP/HTTP Connection
- `compliance/otlp-exporter.md` — Retry
