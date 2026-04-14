# Metrics ETS Key Optimization

## Question

Should the metrics_tab ETS key structure be optimized for atomic CAS operations by converting native types (map/struct) to ETS match-spec friendly types (binary/tuple)?

## Decision

TBD — depends on performance profiling results after the metrics pipeline is complete.

See [Aggregation Types — Future Optimization](aggregation-types.md) for background.
