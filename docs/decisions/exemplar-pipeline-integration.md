# Exemplar Pipeline Integration

## Question

How to wire Exemplar offer/collect into the aggregation and collection pipeline? Currently Exemplar modules exist but are not invoked during record() or MetricReader.collect().

## Decision

### Offer During Aggregation

`Meter.record()` and `Meter.apply_observations()` now call
`offer_exemplar/7` after each aggregation. This function:
1. Gets or creates the reservoir for the timeseries (from
   `exemplars_tab` ETS, keyed by `agg_key`)
2. Calls `Reservoir.offer_to/6` with the configured filter
3. Stores the updated reservoir state back in ETS

Reservoir instances are lazily created on first offer, using
the stream's `exemplar_reservoir` module and appropriate options
(boundaries for histogram, size=1 for others).

### Collect During MetricReader

`MetricReader.collect_stream/2` attaches exemplars to each
datapoint via `attach_exemplars/3`. For each datapoint:
1. Looks up reservoir by `agg_key` in `exemplars_tab`
2. Calls `Reservoir.collect_from/1` to get exemplars and reset
3. Stores the reset reservoir for the next collection cycle

### Infrastructure

- `exemplars_tab` ETS (set, public) added to MeterProvider
- `exemplar_filter` passed through `reader_meter_config` and
  `meter_config` for the offer path
- Current context obtained via `Otel.API.Ctx.get_current/0` at
  record time for trace correlation

### Modules

| Module | Changes |
|---|---|
| `Otel.SDK.Metrics.MeterProvider` | Added `exemplars_tab`, pass `exemplar_filter` to reader config |
| `Otel.SDK.Metrics.Meter` | `offer_exemplar/7`, `get_reservoir/3`, `put_reservoir/3`, `reservoir_opts/1` |
| `Otel.SDK.Metrics.MetricReader` | `attach_exemplars/3`, `collect_exemplar_for_datapoint/3` |

## Compliance

- [Metrics SDK](../compliance.md)
  * Exemplar — L1100, L1104
  * ExemplarReservoir — L1151, L1181
