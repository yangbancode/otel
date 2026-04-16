# Metrics Temporality

## Question

How to implement Delta and Cumulative temporality conversion in the collection pipeline?

## Decision

Per-reader aggregation state with checkpoint-and-reset for Delta temporality.

### Temporality Types

- **Cumulative**: Values accumulate from a fixed start point. Successive data points repeat the same start_time.
- **Delta**: Values reset each collection interval. Successive data points advance start_time.

### Default Temporality

Per the spec, the SDK default output temporality is Cumulative for all instrument kinds. Each reader can override with its own temporality mapping per instrument kind.

### Per-Reader Isolation

Each MetricReader gets a unique `reader_id` (reference). Streams are created per reader with reader-specific temporality. ETS aggregation keys include `reader_id` to isolate per-reader state: `{stream_name, scope, reader_id, attributes}`.

### Delta Checkpoint-and-Reset

For Delta temporality, the `collect` function reads current values and atomically subtracts them from the shared ETS entry:

- **Sum**: `ets:update_counter` with negative value for integers; CAS subtract for floats. Start_time advances to `now`.
- **ExplicitBucketHistogram**: `:counters.sub` for bucket counts; `ets:update_counter` for count; CAS subtract for sum. Min/max reset to `:unset`. Start_time advances to `now`.
- **LastValue (Gauge)**: No temporality concept. Always reports last value.

Entries with zero delta (no new measurements since last collection) are filtered out.

### Metric Output

Collection output includes:

- `temporality`: `:cumulative` or `:delta` (nil for Gauge)
- `is_monotonic`: `true` for Counter and ObservableCounter, `false` otherwise (nil for Gauge)

### Instrument Default Temporality

Instruments have a native temporality (not used for output, but documents the nature of measurements):

| Instrument | Native Temporality |
|---|---|
| Counter, UpDownCounter, Histogram | Delta |
| ObservableCounter, ObservableGauge, ObservableUpDownCounter | Cumulative |

### Not Implemented

- **Temporality conversion for asynchronous instruments**: Observable instruments with Delta reader temporality require cumulative-to-delta conversion (subtracting previous observation). This requires generation-based checkpoint tracking and is deferred.
- **Generation tracking**: The erlang reference uses per-reader generation counters for atomic checkpoint management. The current implementation uses direct read-and-reset, which is correct for single-threaded collection (serialized by GenServer) but lacks crash recovery.

## Compliance

- [Metrics SDK](../compliance.md)
  * MetricReader — L1306, L1321, L1339, L1342, L1354, L1357, L1367
