# Composite Propagator & Global Registration

## Question

How to compose multiple propagators and register them globally on BEAM?

## Decision

### Composite Propagator: `Otel.API.Propagator.TextMap.Composite`

Location: `apps/otel_api/lib/otel/api/propagator/text_map/composite.ex`

Groups multiple TextMapPropagators into a single entity via `new/1`:

```elixir
composite = Otel.API.Propagator.TextMap.Composite.new([
  Otel.API.Propagator.TraceContext,
  Otel.API.Propagator.Baggage  # future
])
```

Returns `{Otel.API.Propagator.TextMap.Composite, propagators}` tuple.

- **inject**: calls each propagator's inject in order on the same carrier
- **extract**: calls each propagator's extract in order, threading context through each
- **fields**: returns union of all propagator fields (deduplicated)

### Global Registration: `Otel.API.Propagator`

Location: `apps/otel_api/lib/otel/api/propagator.ex`

Uses `persistent_term` for storage, matching the TracerProvider pattern.

| Function | Description |
|---|---|
| `set_text_map_propagator(propagator)` | Registers global propagator |
| `get_text_map_propagator()` | Returns registered propagator or nil |

Without registration, all propagation operations are no-ops (carriers pass through unchanged).

### Design Notes

- Follows opentelemetry-erlang: global registration in `persistent_term`, composite via tuple
- No pre-configured default (no-op). SDK or user must explicitly register propagators
- Baggage propagator will be added when Baggage API is implemented

## Compliance

- [API Propagators](../compliance.md)
  * Composite Propagator — L261, L272
  * Global Propagators — L310, L311, L322, L329, L332, L336, L342
  * Propagators Distribution — L352
