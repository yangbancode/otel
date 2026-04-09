# Asynchronous Instruments & Callbacks

## Question

How to implement asynchronous instruments and callback registration/execution on BEAM? How do callbacks interact with process boundaries?

## Decision

TBD

## Compliance

- [Metrics API](../compliance/metrics-api.md)
  * Instrument — [L194](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L194)
  * Asynchronous Instrument API — [L357](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L357)
  * Asynchronous Instrument API — [L361](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L361)
  * Asynchronous Instrument API — [L363](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L363)
  * Asynchronous Instrument API — [L366](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L366)
  * Asynchronous Instrument API — [L368](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L368)
  * Asynchronous Instrument API — [L373](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L373)
  * Asynchronous Instrument API — [L377](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L377)
  * Asynchronous Instrument API — [L379](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L379)
  * Asynchronous Instrument API — [L383](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L383)
  * Asynchronous Instrument API — [L387](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L387)
  * Asynchronous Instrument API — [L395](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L395)
  * Asynchronous Instrument API — [L400](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L400)
  * Asynchronous Instrument API — [L405](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L405)
  * Asynchronous Instrument API — [L408](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L408)
  * Asynchronous Instrument API — [L415](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L415)
  * Asynchronous Instrument API — [L419](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L419)
  * Asynchronous Instrument API — [L422](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L422)
  * Asynchronous Instrument API — [L428](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L428)
  * Asynchronous Instrument API — [L430](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L430)
  * Asynchronous Instrument API — [L431](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L431)
  * Asynchronous Instrument API — [L446](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L446)
  * Asynchronous Instrument API — [L452](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L452)
  * Asynchronous Instrument API — [L455](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L455)
  * Asynchronous Instrument API — [L462](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L462)
  * Asynchronous Instrument API — [L467](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L467)
  * Counter — [L512](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L512)
  * Asynchronous Counter — [L615](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L615)
  * Asynchronous Counter — [L652](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L652)
  * Asynchronous Counter — [L655](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L655)
  * Gauge — [L854](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L854)
  * Asynchronous Gauge — [L936](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L936)
  * UpDownCounter — [L1086](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1086)
  * Asynchronous UpDownCounter — [L1178](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1178)
  * Measurement — [L1294](../references/opentelemetry-specification/v1.55.0/metrics/api.md#L1294)
