# View System

## Question

How to implement the View system (instrument selection criteria + stream configuration + measurement processing) on BEAM?

## Decision

### View Struct

A View pairs selection criteria with stream configuration. Both are
maps with all keys optional.

Selection criteria are additive (AND): an instrument must match all
provided criteria. Supported criteria: `name`, `type`, `unit`,
`meter_name`, `meter_version`, `meter_schema_url`. The wildcard
name `"*"` matches all instruments. A wildcard view must not specify
a stream name (returns error on creation).

Stream configuration: `name`, `description`, `attribute_keys`,
`aggregation`, `aggregation_options`, `exemplar_reservoir`,
`aggregation_cardinality_limit`. All optional — defaults fall back
to instrument values or advisory parameters.

### Stream Struct

A Stream is the output of matching a View to an Instrument. It holds
the resolved name, description, attribute filter, and references to
aggregation/exemplar/cardinality config (placeholders until those
Decisions are implemented).

When no View matches, a default stream is created from the instrument.
Advisory `attributes` parameter is honored as `{:include, keys}` when
no view attribute_keys are configured.

### Attribute Filtering

Two modes: `{:include, keys}` (allow-list) and `{:exclude, keys}`
(exclude-list). View config takes precedence over advisory parameters.
When neither is set, all attributes are kept.

### View Registration

Views are registered on MeterProvider via `add_view/3` GenServer call.
Views are appended in order and passed to meters via config. Updated
views apply to all subsequently created meters (configuration owned
by MeterProvider, per spec L144/L150).

### Measurement Processing

Instrument → View matching in `Meter.match_views/2`:
- Filters views by `View.matches?/2` against the instrument
- Each matching view produces a stream via `Stream.from_view/2`
- No matches: single default stream via `Stream.from_instrument/1`
- Conflicting stream names: warning emitted, all streams kept

### Deferred to Subsequent Decisions

- Per-reader stream creation (MetricReader Decision)
- Aggregation module resolution and defaults (Aggregation Types)
- Exemplar reservoir defaults (Exemplar System)
- Cardinality limit enforcement (Async Observations & Cardinality)
- Retroactive view-instrument matching on add_view (MetricReader)
- Stream creation on instrument registration (MetricReader)

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Metrics.View` | `apps/otel_sdk/lib/otel/sdk/metrics/view.ex` | View struct, matching, attribute filtering |
| `Otel.SDK.Metrics.Stream` | `apps/otel_sdk/lib/otel/sdk/metrics/stream.ex` | Stream struct from view/instrument |

## Compliance

- [Metrics SDK](../compliance.md)
  * Configuration — L144, L150
  * View (Stable) — L252, L253, L257
  * Instrument Selection Criteria — L264, L270, L288, L293, L299, L305, L311, L316, L323, L331
  * Stream Configuration — L339, L343, L352, L353, L355, L360, L361, L364, L372, L373, L376, L378, L380, L390, L391, L402, L404, L412, L414
  * Measurement Processing — L420, L428, L439, L446, L448
