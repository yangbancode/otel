# OTLP gRPC Exporter

## Question

How to implement the OTLP gRPC exporter on BEAM? gRPC client library choice, unary calls, concurrent request support, status code handling?

## Decision

TBD

## Compliance

- [OTLP Protocol](../compliance/otlp-protocol.md)
  * OTLP/gRPC Concurrent Requests — [L129](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L129)
  * OTLP/gRPC Concurrent Requests — [L130](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L130)
  * OTLP/gRPC Concurrent Requests — [L137](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L137)
  * OTLP/gRPC Concurrent Requests — [L151](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L151)
  * OTLP/gRPC Concurrent Requests — [L155](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L155)
  * OTLP/gRPC Response — [L160](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L160)
  * Full Success (gRPC) — [L170](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L170)
  * Full Success (gRPC) — [L172](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L172)
  * Full Success (gRPC) — [L178](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L178)
  * Partial Success (gRPC) — [L185](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L185)
  * Partial Success (gRPC) — [L189](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L189)
  * Partial Success (gRPC) — [L197](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L197)
  * Partial Success (gRPC) — [L205](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L205)
  * Partial Success (gRPC) — [L208](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L208)
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
  * OTLP/gRPC Default Port — [L381](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L381)
- [OTLP Exporter Configuration](../compliance/otlp-exporter.md)
  * Configuration Options — [L13](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L13)
  * Configuration Options — [L14](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L14)
  * Configuration Options — [L17](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L17)
  * Configuration Options — [L26](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L26)
  * Configuration Options — [L71](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L71)
  * Configuration Options — [L77](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L77)
  * Configuration Options — [L83](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L83)
  * Specify Protocol — [L169](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L169)
  * Specify Protocol — [L170](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L170)
  * Specify Protocol — [L173](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L173)
  * User Agent — [L205](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L205)
  * User Agent — [L211](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L211)
