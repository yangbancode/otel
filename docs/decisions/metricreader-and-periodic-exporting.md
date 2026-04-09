# MetricReader & Periodic Exporting

## Question

How to implement MetricReader interface and PeriodicExportingMetricReader on BEAM? Collection pipeline, temporality handling, scheduling?

## Decision

TBD

## Compliance

- [Metrics SDK](../compliance/metrics-sdk.md)
  * Shutdown — [L191](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L191)
  * Shutdown — [L193](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L193)
  * Shutdown — [L196](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L196)
  * Shutdown — [L198](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L198)
  * Shutdown — [L203](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L203)
  * Shutdown — [L1430](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1430)
  * Shutdown — [L1431](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1431)
  * Shutdown — [L1434](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1434)
  * Shutdown — [L1437](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1437)
  * ForceFlush — [L216](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L216)
  * ForceFlush — [L219](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L219)
  * ForceFlush — [L220](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L220)
  * ForceFlush — [L225](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L225)
  * MetricReader (Stable) — [L1302](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1302)
  * MetricReader (Stable) — [L1305](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1305)
  * MetricReader (Stable) — [L1306](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1306)
  * MetricReader (Stable) — [L1307](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1307)
  * MetricReader (Stable) — [L1318](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1318)
  * MetricReader (Stable) — [L1321](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1321)
  * MetricReader (Stable) — [L1339](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1339)
  * MetricReader (Stable) — [L1342](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1342)
  * MetricReader (Stable) — [L1345](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1345)
  * MetricReader (Stable) — [L1354](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1354)
  * MetricReader (Stable) — [L1357](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1357)
  * MetricReader (Stable) — [L1359](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1359)
  * MetricReader (Stable) — [L1365](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1365)
  * MetricReader (Stable) — [L1367](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1367)
  * MetricReader (Stable) — [L1374](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1374)
  * MetricReader (Stable) — [L1391](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1391)
  * Collect — [L1406](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1406)
  * Collect — [L1416](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1416)
  * Periodic Exporting MetricReader — [L1455](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1455)
  * ForceFlush (Periodic) — [L1478](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1478)
  * ForceFlush (Periodic) — [L1482](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1482)
  * ForceFlush (Periodic) — [L1483](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1483)
  * ForceFlush (Periodic) — [L1488](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1488)
