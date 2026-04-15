# Metrics Temporality

## Question

How to implement Delta and Cumulative temporality conversion in the collection pipeline? Currently all aggregations are cumulative-only with no checkpoint/reset mechanism.

## Decision

TBD — requires:
- Per-reader temporality configuration (from exporter or default Cumulative)
- Checkpoint mechanism in aggregation modules (snapshot + reset for Delta)
- Generation tracking to isolate reader collections
- StartTimeUnixNano handling (repeat for Cumulative, advance for Delta)

## Compliance

- [Metrics SDK](../compliance.md)
  * MetricReader — L1321, L1339, L1342, L1345, L1354, L1357
