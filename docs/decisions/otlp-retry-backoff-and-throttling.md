# OTLP Retry, Backoff & Throttling

## Question

How to implement shared retry strategy for OTLP exporters? Exponential backoff with jitter, RetryInfo handling, status code mapping?

## Decision

Deferred. The spec recommends (SHOULD) retry with exponential backoff for transient failures (429, 502, 503, 504), but opentelemetry-erlang does not implement retry either. The current exporter returns `:error` on failure and relies on the batch processor to handle data loss.

Will revisit when production usage requires retry reliability.

## Compliance

- [OTLP Protocol](../compliance.md)
  * Failures (gRPC) — L217, L222, L226, L228, L269, L291, L295
  * OTLP/gRPC Throttling — L309, L310, L312, L344, L365
  * Failures (HTTP) — L541, L545, L554, L560, L562, L566, L568
  * OTLP/HTTP Throttling — L592, L597, L600
  * All Other Responses — L608
  * OTLP/HTTP Connection — L614, L618, L620
- [OTLP Exporter Configuration](../compliance.md)
  * Retry — L184, L184
