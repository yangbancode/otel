# Asynchronous Instruments & Callbacks

## Question

How to implement asynchronous instruments and callback registration/execution on BEAM? How do callbacks interact with process boundaries?

## Decision

### Architecture

Each async instrument is a thin facade module that delegates to `Otel.API.Metrics.Meter` for creation. Creation returns an `Otel.API.Metrics.Instrument.t()` handle — same struct as synchronous instruments; see [api-instrument-struct.md](api-instrument-struct.md). Supports two creation styles:

1. **Without callback** (`create/3`) — instrument created, callback registered later via `Meter.register_callback/5` passing the list of Instrument handles.
2. **With inline callback** (`create/5`) — callback permanently attached at creation time

### Callback Model

Callbacks are 1-arity functions receiving `callback_args` (any term for state passing). On BEAM, closures naturally capture state, and `callback_args` provides an additional explicit mechanism per spec SHOULD (`metrics/api.md` L467-L470).

Return shapes are spec-defined and differ between the two registration paths:

- **Inline per-instrument callbacks** (`create_observable_counter/5` and siblings) return `[Otel.API.Metrics.Measurement.t()]` per `metrics/api.md` L441-L442 *"Return a list (or tuple, generator, enumerator, etc.) of individual Measurement values"*.
- **Multi-instrument callbacks** (`Meter.register_callback/5`) return `[{Otel.API.Metrics.Instrument.t(), Otel.API.Metrics.Measurement.t()}]` — a flat list of `(Instrument, Measurement)` pairs per `metrics/api.md` L1302-L1303 and the L452-L453 MUST that *"Idiomatic APIs for multiple-instrument Callbacks MUST distinguish the instrument associated with each observed Measurement value"*.

The SDK normalises both shapes internally: single-shape observations are wrapped with the one registered instrument so the post-callback pipeline sees `[{Instrument, Measurement}]` uniformly (`apps/otel_sdk/lib/otel/sdk/metrics/meter.ex` `invoke_callback_and_normalize/1`).

### Callback Execution

Callback evaluation is an SDK responsibility. The API layer only handles registration. The SDK evaluates each registered callback exactly once per collection cycle, reports observations with identical timestamps, and handles MetricReader independence.

### No Recording Functions

Unlike synchronous instruments, async instruments have no `add` or `record` functions. Observations are produced exclusively through callbacks invoked by the SDK during collection.

### Callback Unregistration

`Meter.register_callback/5` returns an opaque `{module, state}` registration
handle (the same `{dispatcher_module, state}` shape used by Tracer/Meter/Logger
themselves). `Meter.unregister_callback/1` takes that handle, unwraps it, and
dispatches to `module.unregister_callback(state)`. After this call the callback
is no longer evaluated during collection. This satisfies the Spec MUST at
`metrics/api.md` L419.

Noop returns `{Noop, :noop}` from `register_callback/5` and `:ok` from
`unregister_callback/1`.

### Instrument Modules

| Module | Semantics | Value |
|---|---|---|
| `Otel.API.Metrics.ObservableCounter` | Monotonically increasing absolute value | non-negative |
| `Otel.API.Metrics.ObservableGauge` | Non-additive point-in-time value | any |
| `Otel.API.Metrics.ObservableUpDownCounter` | Additive absolute value (can increase/decrease) | any |

### No-op Behavior

Without SDK: creation returns an `Otel.API.Metrics.Instrument.t()` with only identifying fields; `register_callback` returns an opaque `{Noop, :noop}` registration handle (which `unregister_callback/1` accepts and no-ops on). Callbacks are never invoked.

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.API.Metrics.ObservableCounter` | `apps/otel_api/lib/otel/api/metrics/observable_counter.ex` | Observable Counter facade |
| `Otel.API.Metrics.ObservableGauge` | `apps/otel_api/lib/otel/api/metrics/observable_gauge.ex` | Observable Gauge facade |
| `Otel.API.Metrics.ObservableUpDownCounter` | `apps/otel_api/lib/otel/api/metrics/observable_updown_counter.ex` | Observable UpDownCounter facade |

## Compliance

- [Metrics API](../compliance.md)
  * Instrument — L194
  * Asynchronous Instrument API — L357, L361, L363, L366, L368, L373, L377, L379, L383, L387, L395, L400, L405, L408, L415, L419, L422, L428, L430, L431, L446, L452, L455, L462, L467
  * Asynchronous Counter — L615, L652, L655
  * Asynchronous Gauge — L936
  * Asynchronous UpDownCounter — L1178
  * Measurement — L1294
