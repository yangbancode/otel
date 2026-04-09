# Exemplar System

## Question

How to implement the Exemplar sampling subsystem (ExemplarFilter, ExemplarReservoir, built-in reservoirs) on BEAM?

## Decision

TBD

## Compliance

- [Metrics SDK](../compliance/metrics-sdk.md)
  * Exemplar (Stable) — [L1100](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1100)
  * Exemplar (Stable) — [L1103](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1103)
  * Exemplar (Stable) — [L1104](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1104)
  * Exemplar (Stable) — [L1106](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1106)
  * Exemplar (Stable) — [L1110](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1110)
  * ExemplarFilter — [L1117](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1117)
  * ExemplarFilter — [L1122](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1122)
  * ExemplarFilter — [L1123](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1123)
  * ExemplarFilter — [L1124](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1124)
  * ExemplarFilter — [L1126](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1126)
  * ExemplarReservoir — [L1148](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1148)
  * ExemplarReservoir — [L1151](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1151)
  * ExemplarReservoir — [L1155](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1155)
  * ExemplarReservoir — [L1164](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1164)
  * ExemplarReservoir — [L1172](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1172)
  * ExemplarReservoir — [L1179](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1179)
  * ExemplarReservoir — [L1181](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1181)
  * ExemplarReservoir — [L1186](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1186)
  * ExemplarReservoir — [L1192](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1192)
  * Exemplar Defaults — [L1196](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1196)
  * Exemplar Defaults — [L1203](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1203)
  * Exemplar Defaults — [L1205](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1205)
  * Exemplar Defaults — [L1209](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1209)
  * SimpleFixedSizeExemplarReservoir — [L1218](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1218)
  * SimpleFixedSizeExemplarReservoir — [L1235](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1235)
  * SimpleFixedSizeExemplarReservoir — [L1242](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1242)
  * AlignedHistogramBucketExemplarReservoir — [L1246](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1246)
  * AlignedHistogramBucketExemplarReservoir — [L1247](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1247)
  * AlignedHistogramBucketExemplarReservoir — [L1248](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1248)
  * AlignedHistogramBucketExemplarReservoir — [L1276](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1276)
  * Custom ExemplarReservoir — [L1282](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1282)
  * Custom ExemplarReservoir — [L1283](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1283)
  * Custom ExemplarReservoir — [L1284](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1284)
