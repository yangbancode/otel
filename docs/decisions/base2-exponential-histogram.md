# Base2 Exponential Bucket Histogram

## Question

How to implement Base2 Exponential Bucket Histogram aggregation on BEAM? This is a SHOULD-level requirement with dynamic bucket scaling.

## Decision

TBD — requires:
- Exponential bucket mapping with configurable MaxSize (default 160) and MaxScale (default 20)
- Dynamic scale adjustment to maintain best resolution within size constraint
- IEEE float handling: normal range support, +Inf/-Inf/NaN exclusion from sum/min/max
- RecordMinMax support (default true)
- Integration with Exemplar default reservoir selection (SimpleFixedSize with min(20, max_buckets))

## Compliance

- [Metrics SDK](../compliance.md)
  * Aggregation (Stable) — L577
  * Base2 Exponential Bucket Histogram Aggregation — L728, L732, L741, L748, L753
  * Exemplar Defaults — L1205
