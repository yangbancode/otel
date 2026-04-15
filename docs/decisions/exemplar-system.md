# Exemplar System

## Question

How to implement the Exemplar sampling subsystem (ExemplarFilter, ExemplarReservoir, built-in reservoirs) on BEAM?

## Decision

### Exemplar Struct

`Otel.SDK.Metrics.Exemplar` holds: value, time, filtered_attributes,
trace_id, span_id. Trace context is extracted from `Otel.API.Ctx`
at offer time via `Otel.API.Trace.current_span/1`.

### ExemplarFilter

`Otel.SDK.Metrics.Exemplar.Filter` — three built-in filters:
- `:always_on` — sample all
- `:always_off` — never sample
- `:trace_based` — sample when span has sampled trace flag (default)

Configured as MeterProvider parameter `exemplar_filter`, default
`:trace_based`.

### ExemplarReservoir Behaviour

`Otel.SDK.Metrics.Exemplar.Reservoir` defines callbacks:
- `new(opts)` — create initial state
- `offer(state, value, time, filtered_attributes, ctx)` — sample
- `collect(state)` — return `{exemplars, new_state}`

Facade functions `offer_to/6` and `collect_from/1` integrate filter
checks and handle nil reservoir (no-op when sampling is off).

Reservoir state is a `{module, state}` tuple stored per timeseries.

### Built-in Reservoirs

**SimpleFixedSize** — uniformly-weighted random sampling (reservoir
sampling algorithm). Default size 1. Count resets on collect.

**AlignedHistogramBucket** — one exemplar per bucket, aligned with
explicit histogram boundaries. Replaces on each offer.

### Default Reservoir Selection

In `Stream.resolve/1`:
- ExplicitBucketHistogram → AlignedHistogramBucket
- All others → SimpleFixedSize

View's `exemplar_reservoir` takes precedence.

### Deferred

- Integration with aggregation modules (exemplar offer during
  aggregate, collect during metric collection) — MetricReader Decision
- Environment variable configuration for exemplar filter
- Custom ExemplarReservoir via View (structure exists, wiring in
  MetricReader)

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Metrics.Exemplar` | `exemplar.ex` | Exemplar struct |
| `Otel.SDK.Metrics.Exemplar.Filter` | `exemplar/filter.ex` | ExemplarFilter |
| `Otel.SDK.Metrics.Exemplar.Reservoir` | `exemplar/reservoir.ex` | Reservoir behaviour + facade |
| `Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize` | `exemplar/reservoir/simple_fixed_size.ex` | Random sampling |
| `Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket` | `exemplar/reservoir/aligned_histogram_bucket.ex` | Histogram-aligned |

## Compliance

- [Metrics SDK](../compliance.md)
  * Exemplar (Stable) — L1100, L1103, L1104, L1106, L1110
  * ExemplarFilter — L1117, L1122, L1123, L1124, L1126
  * ExemplarReservoir — L1148, L1151, L1155, L1164, L1172, L1179, L1181, L1186, L1192
  * Exemplar Defaults — L1196, L1203, L1205, L1209
  * SimpleFixedSizeExemplarReservoir — L1218, L1235, L1242
  * AlignedHistogramBucketExemplarReservoir — L1246, L1247, L1248, L1276
  * Custom ExemplarReservoir — L1282, L1283, L1284
