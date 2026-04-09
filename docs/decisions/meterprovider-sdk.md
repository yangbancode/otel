# MeterProvider SDK

## Question

How to implement MeterProvider SDK on BEAM? Configuration ownership, Meter creation, Shutdown/ForceFlush cascading?

## Decision

TBD

## Compliance

- [Metrics SDK](../compliance/metrics-sdk.md)
  * General — [L103](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L103)
  * MeterProvider (Stable) — [L109](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L109)
  * MeterProvider (Stable) — [L110](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L110)
  * MeterProvider Creation — [L117](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L117)
  * Meter Creation — [L121](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L121)
  * Meter Creation — [L124](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L124)
  * Meter Creation — [L126](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L126)
  * Meter Creation — [L131](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L131)
  * Meter Creation — [L132](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L132)
  * Meter Creation — [L133](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L133)
  * Configuration — [L144](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L144)
  * Configuration — [L150](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L150)
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
  * Defaults and Configuration — [L1837](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1837)
  * Compatibility Requirements (Stable) — [L1862](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1862)
  * Compatibility Requirements (Stable) — [L1865](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1865)
  * Concurrency Requirements (Stable) — [L1875](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1875)
  * Concurrency Requirements (Stable) — [L1878](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1878)
  * Concurrency Requirements (Stable) — [L1880](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1880)
  * Concurrency Requirements (Stable) — [L1883](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1883)
