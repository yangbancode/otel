# Synchronous Instruments

## Question

How to implement synchronous instruments (Counter, Histogram, Gauge, UpDownCounter) and their common creation/recording API on BEAM?

## Decision

### Architecture

Each instrument is a thin facade module that delegates to `Otel.API.Metrics.Meter`. Creation returns an `Otel.API.Metrics.Instrument.t()` handle; recording takes that handle and dispatches via the meter embedded in it. The handle struct is defined at `apps/otel_api/lib/otel/api/metrics/instrument.ex`.

### Recording Path

All synchronous instruments record through a single `Meter.record/3` dispatch:

```
Counter.add/3        \
Histogram.record/3    |-->  Meter.record/3  -->  module.record/3
Gauge.record/3        |
UpDownCounter.add/3  /
```

### Instrument Modules

| Module | Create via | Record via | Value |
|---|---|---|---|
| `Otel.API.Metrics.Counter` | `Meter.create_counter/3` | `add/3` | non-negative |
| `Otel.API.Metrics.Histogram` | `Meter.create_histogram/3` | `record/3` | non-negative |
| `Otel.API.Metrics.Gauge` | `Meter.create_gauge/3` | `record/3` | any |
| `Otel.API.Metrics.UpDownCounter` | `Meter.create_updown_counter/3` | `add/3` | any |

### Common Parameters

Instrument creation accepts `name` (required) and optional keyword opts:
- `:unit` — case-sensitive ASCII string, max 63 characters
- `:description` — opaque string, supports BMP, at least 1023 characters
- `:advisory` — keyword list (e.g. `explicit_bucket_boundaries` for Histogram)

Recording accepts `instrument`, `value` (number), and `attributes` (map, optional). The instrument carries its own meter reference — no separate meter argument at the call site.

### No-op Behavior

Without SDK: creation returns an `Otel.API.Metrics.Instrument.t()` with only identifying fields populated (and `meter` pointing at the Noop meter). `record/3` is a no-op, `enabled?/2` returns `false`. No validation at the API level — name/unit/value validation is deferred to SDK.

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.API.Metrics.Counter` | `apps/otel_api/lib/otel/api/metrics/counter.ex` | Counter facade |
| `Otel.API.Metrics.Histogram` | `apps/otel_api/lib/otel/api/metrics/histogram.ex` | Histogram facade |
| `Otel.API.Metrics.Gauge` | `apps/otel_api/lib/otel/api/metrics/gauge.ex` | Gauge facade |
| `Otel.API.Metrics.UpDownCounter` | `apps/otel_api/lib/otel/api/metrics/updown_counter.ex` | UpDownCounter facade |

## Spec references

- `opentelemetry-specification/specification/metrics/api.md`
  * Instrument — L194
  * Instrument unit — L225, L223
  * Instrument description — L235, L237, L242
  * Instrument advisory parameters — L254
  * Synchronous Instrument API — L304-L348
  * General operations (Enabled) — L475, L487, L489, L494
  * Counter — L512, L549-L577
  * Histogram — L748, L785-L804
  * Gauge — L854, L880-L902
  * UpDownCounter — L1086, L1122-L1136
