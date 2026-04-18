# MeterProvider & Meter API

## Question

How to implement MeterProvider and Meter API on BEAM? Global registration, get-meter, no-op provider?

## Decision

### Global Registration

Use `persistent_term` for global MeterProvider storage, same pattern as TracerProvider. Fast read access, shared across all processes.

### Meter Representation

A Meter is a `{module, config}` tuple, same as Tracer. The module implements the `Otel.API.Metrics.Meter` behaviour. Without SDK installed, the default is `{Otel.API.Metrics.Meter.Noop, []}`.

### Get a Meter

`get_meter/1,2,3,4` accepts name (required), version (optional), schema_url (optional), attributes (optional). Returns a Meter tuple. Invalid name (nil or empty) returns a working Meter with empty name and logs a warning.

Meters are cached in `persistent_term` keyed by `{prefix, {name, version, schema_url}}`.

### Meter Behaviour

Meter defines callbacks for creating all seven instrument kinds:

- Synchronous: `create_counter`, `create_histogram`, `create_gauge`, `create_updown_counter`
- Asynchronous: `create_observable_counter`, `create_observable_gauge`, `create_observable_updown_counter`

Plus `register_callback` for multi-instrument async callbacks and `enabled?` for checking if the meter is active.

### No-op Behavior

When no SDK is installed:
- `get_meter` returns the noop meter
- Instrument creation returns an `Otel.API.Metrics.Instrument.t()` with identifying fields populated and `meter` pointing at the Noop meter (see [api-instrument-struct.md](api-instrument-struct.md))
- `record/3` on that instrument is a no-op
- `enabled?` returns `false`
- `register_callback` returns `:ok`

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.API.Metrics.MeterProvider` | `apps/otel_api/lib/otel/api/metrics/meter_provider.ex` | Global registration, get_meter |
| `Otel.API.Metrics.Meter` | `apps/otel_api/lib/otel/api/metrics/meter.ex` | Meter behaviour + dispatch |
| `Otel.API.Metrics.Meter.Noop` | `apps/otel_api/lib/otel/api/metrics/meter/noop.ex` | No-op meter implementation |

## Compliance

- [Metrics API](../compliance.md)
  * MeterProvider — L111, L116
  * Get a Meter — L122, L138, L144, L150
  * Meter — L161, L166
  * Compatibility requirements — L1334, L1337
  * Concurrency requirements — L1345, L1348, L1351
