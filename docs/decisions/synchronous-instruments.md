# Synchronous Instruments

## Question

How to implement synchronous instruments (Counter, Histogram, Gauge, UpDownCounter) and their common creation/recording API on BEAM?

## Decision

### Architecture

Each instrument is a thin facade module that delegates to `Otel.API.Metrics.Meter` for both creation and recording. Following the opentelemetry-erlang pattern, instruments are identified by name through the Meter — no opaque instrument handle is needed at the API level.

### Recording Path

All synchronous instruments record through a single `Meter.record/5` dispatch:

```
Counter.add/4        \
Histogram.record/4    |-->  Meter.record/5  -->  module.record/5
Gauge.record/4        |
UpDownCounter.add/4  /
```

### Instrument Modules

| Module | Create via | Record via | Value |
|---|---|---|---|
| `Otel.API.Metrics.Counter` | `Meter.create_counter/3` | `add/4` | non-negative |
| `Otel.API.Metrics.Histogram` | `Meter.create_histogram/3` | `record/4` | non-negative |
| `Otel.API.Metrics.Gauge` | `Meter.create_gauge/3` | `record/4` | any |
| `Otel.API.Metrics.UpDownCounter` | `Meter.create_updown_counter/3` | `add/4` | any |

### Common Parameters

Instrument creation accepts `name` (required) and optional keyword opts:
- `:unit` — case-sensitive ASCII string, max 63 characters
- `:description` — opaque string, supports BMP, at least 1023 characters
- `:advisory` — keyword list (e.g. `explicit_bucket_boundaries` for Histogram)

Recording accepts `meter`, `name`, `value` (number), and `attributes` (map, optional).

### No-op Behavior

Without SDK: creation returns `:ok`, recording returns `:ok`, `enabled?` returns `false`. No validation at the API level — name/unit/value validation is deferred to SDK.

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.API.Metrics.Counter` | `apps/otel_api/lib/otel/api/metrics/counter.ex` | Counter facade |
| `Otel.API.Metrics.Histogram` | `apps/otel_api/lib/otel/api/metrics/histogram.ex` | Histogram facade |
| `Otel.API.Metrics.Gauge` | `apps/otel_api/lib/otel/api/metrics/gauge.ex` | Gauge facade |
| `Otel.API.Metrics.UpDownCounter` | `apps/otel_api/lib/otel/api/metrics/updown_counter.ex` | UpDownCounter facade |

## Compliance

- [Metrics API](../compliance.md)
  * Instrument — L194
  * Instrument unit — L225, L223
  * Instrument description — L235, L237, L242
  * Instrument advisory parameters — L254
  * Synchronous Instrument API — L304, L308, L310, L313, L315, L320, L324, L326, L331, L334, L343, L348
  * General operations (Enabled) — L475, L487, L489, L494
  * Counter — L512, L549, L552, L557, L558, L562, L563, L569, L577
  * Histogram — L748, L785, L788, L792, L794, L797, L799, L804
  * Gauge — L854, L880, L883, L888, L889, L894, L902
  * UpDownCounter — L1086, L1122, L1125, L1129, L1131, L1136
