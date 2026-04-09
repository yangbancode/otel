# OTLP Retry, Backoff & Throttling

## Question

How to implement shared retry strategy for OTLP exporters? Exponential backoff with jitter, RetryInfo handling, status code mapping?

## Decision

TBD

## Compliance

- [OTLP Protocol](../compliance/otlp-protocol.md)
  * Failures (gRPC) — [L217](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L217)
  * Failures (gRPC) — [L222](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L222)
  * Failures (gRPC) — [L226](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L226)
  * Failures (gRPC) — [L228](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L228)
  * Failures (gRPC) — [L269](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L269)
  * Failures (gRPC) — [L291](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L291)
  * Failures (gRPC) — [L295](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L295)
  * OTLP/gRPC Throttling — [L309](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L309)
  * OTLP/gRPC Throttling — [L310](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L310)
  * OTLP/gRPC Throttling — [L312](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L312)
  * OTLP/gRPC Throttling — [L344](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L344)
  * OTLP/gRPC Throttling — [L365](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L365)
  * Failures (HTTP) — [L541](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L541)
  * Failures (HTTP) — [L545](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L545)
  * Failures (HTTP) — [L554](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L554)
  * Failures (HTTP) — [L560](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L560)
  * Failures (HTTP) — [L562](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L562)
  * Failures (HTTP) — [L566](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L566)
  * Failures (HTTP) — [L568](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L568)
  * OTLP/HTTP Throttling — [L592](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L592)
  * OTLP/HTTP Throttling — [L597](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L597)
  * OTLP/HTTP Throttling — [L600](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L600)
  * All Other Responses — [L608](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L608)
  * OTLP/HTTP Connection — [L614](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L614)
  * OTLP/HTTP Connection — [L618](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L618)
  * OTLP/HTTP Connection — [L620](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L620)
- [OTLP Exporter Configuration](../compliance/otlp-exporter.md)
  * Retry — [L184](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L184)
  * Retry — [L184](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L184)
