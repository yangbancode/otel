# Aggregation Types

## Question

How to implement aggregation algorithms (Drop, Default, Sum, LastValue, ExplicitBucketHistogram, Base2ExponentialHistogram) on BEAM?

## Decision

### Aggregation Behaviour

`Otel.SDK.Metrics.Aggregation` defines two callbacks:
- `aggregate(metrics_tab, key, value, opts)` — update aggregation state
- `collect(metrics_tab, stream_key, opts)` — read accumulated datapoints

### Default Mapping

`Aggregation.default_module/1` maps instrument kind to aggregation:
- Counter, UpDownCounter, ObservableCounter, ObservableUpDownCounter → Sum
- Gauge, ObservableGauge → LastValue
- Histogram → ExplicitBucketHistogram

### Drop

No-op. aggregate stores nothing, collect returns empty.

### Sum

Stores `{key, int_value, float_value, start_time}` in ETS.
Integer values use `ets:update_counter` (atomic). Float values
use `ets:update_element` after lookup. Collect returns int+float
combined as the sum value.

### LastValue

Stores `{key, value, timestamp, start_time}` in ETS.
Uses `ets:insert_new` for first write, `ets:update_element` for
subsequent. Last writer wins — correct for gauge semantics.

### ExplicitBucketHistogram

Stores `{key, counters_ref, min, max, sum, count, start_time}`.
Uses `:counters` module for thread-safe bucket increments.
Count uses `ets:update_counter`. Integer sum uses `update_counter`,
float sum uses `update_element`. Min/max use `update_element` with
comparison guard.

Default boundaries: `[0, 5, 10, 25, 50, 75, 100, 250, 500, 750,
1000, 2500, 5000, 7500, 10000]` (16 buckets).

Advisory `explicit_bucket_boundaries` are merged into stream
aggregation_options via `Stream.resolve/1`.

### ETS Tables

MeterProvider creates `metrics_tab` (set, public) and `streams_tab`
(bag, public) alongside `instruments_tab`. All passed to meters
through config.

### Record Flow

1. Instrument registered → views matched → streams resolved and
   cached in `streams_tab`
2. `record(meter, name, value, attributes)` → lookup streams →
   filter attributes → call aggregation module

### Deferred

- Base2 Exponential Bucket Histogram (SHOULD, not MUST)
- Sum monotonicity metadata (needed at export time)
- RecordMinMax configuration (always true, correct default)
- Histogram sum suppression for negative instruments (SHOULD)
- Temporality handling (MetricReader Decision)

### Future Optimization

The metrics_tab key is `{stream_name, scope, filtered_attributes}`
where scope is an `%InstrumentationScope{}` struct and attributes
is a map. This prevents use of `ets:select_replace` for atomic CAS
operations because ETS match specs do not support map literals in
patterns.

Current approach uses `ets:update_element` which is atomic per field
but not per entry. This is acceptable since concurrent races on the
same key (same stream + same attribute set) are rare in practice.

If performance profiling reveals contention, consider:
- Convert attributes to `:erlang.term_to_binary(sorted_attrs)` for
  the key (Erlang reference approach)
- Replace scope struct with a simple `{name, version}` tuple
- This would make keys ETS match-spec friendly and enable
  `ets:select_replace` for true CAS on float sum, min, max

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Metrics.Aggregation` | `aggregation.ex` | Behaviour + default mapping |
| `Otel.SDK.Metrics.Aggregation.Drop` | `aggregation/drop.ex` | No-op aggregation |
| `Otel.SDK.Metrics.Aggregation.Sum` | `aggregation/sum.ex` | Arithmetic sum |
| `Otel.SDK.Metrics.Aggregation.LastValue` | `aggregation/last_value.ex` | Last measurement |
| `Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram` | `aggregation/explicit_bucket_histogram.ex` | Bucket histogram |

## Compliance

- [Metrics SDK](../compliance.md)
  * Aggregation (Stable) — L567, L577
  * Histogram Aggregations — L646
  * Explicit Bucket Histogram Aggregation — L661
  * Base2 Exponential Bucket Histogram Aggregation — L728, L732, L741, L748, L753
