# MeterProvider SDK

## Question

How to implement MeterProvider SDK on BEAM? Configuration ownership, Meter creation, Shutdown/ForceFlush cascading?

## Decision

### Architecture

A GenServer that owns metrics configuration (resource, views, readers) and creates SDK Meters. Follows the same pattern as TracerProvider SDK. Registers itself as the global MeterProvider API on start.

### GenServer State

```elixir
%{
  resource: Otel.SDK.Resource.t(),
  views: [term()],
  readers: [{module(), map()}],
  shut_down: boolean()
}
```

### Get a Meter

Returns `{Otel.SDK.Metrics.Meter, config}` where config contains the InstrumentationScope and a reference back to the provider. After shutdown, returns noop meter.

Invalid name (nil or empty): returns a working Meter with the original invalid name, logs a warning.

### Shutdown

Cascades to all registered MetricReaders and MetricExporters. After shutdown, `get_meter` returns noop. Second call returns `{:error, :already_shut_down}`.

### ForceFlush

Cascades to all registered MetricReaders that implement ForceFlush. Returns `:ok` or `{:error, reasons}`.

### SDK Meter

`Otel.SDK.Metrics.Meter` implements the `Otel.API.Metrics.Meter` behaviour. At this stage it is a placeholder that returns `:ok` for all operations. Actual instrument registration, measurement recording, and view processing will be added in subsequent decisions.

### Configuration

Configuration is owned by the MeterProvider and applies retroactively to all Meters returned by it (Meters hold a reference to the provider, not a snapshot).

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Metrics.MeterProvider` | `apps/otel_sdk/lib/otel/sdk/metrics/meter_provider.ex` | MeterProvider GenServer |
| `Otel.SDK.Metrics.Meter` | `apps/otel_sdk/lib/otel/sdk/metrics/meter.ex` | SDK Meter behaviour impl |

## Compliance

- [Metrics SDK](../compliance.md)
  * General — L103
  * MeterProvider (Stable) — L109, L110
  * MeterProvider Creation — L117
  * Meter Creation — L121, L124, L126, L131, L132, L133
  * Configuration — L144, L150
  * Shutdown — L191, L193, L196, L198, L203
  * ForceFlush — L216, L219, L220, L225
  * Defaults and Configuration — L1837
  * Compatibility Requirements (Stable) — L1862, L1865
  * Concurrency Requirements (Stable) — L1875, L1878, L1880, L1883
