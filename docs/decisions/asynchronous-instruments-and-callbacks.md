# Asynchronous Instruments & Callbacks

## Question

How to implement asynchronous instruments and callback registration/execution on BEAM? How do callbacks interact with process boundaries?

## Decision

### Architecture

Each async instrument is a thin facade module that delegates to `Otel.API.Metrics.Meter` for creation. Follows the same pattern as synchronous instruments. Supports two creation styles:

1. **Without callback** (`create/3`) — instrument created, callback registered later via `Meter.register_callback/5`
2. **With inline callback** (`create/5`) — callback permanently attached at creation time

### Callback Model

Callbacks are 1-arity functions receiving `callback_args` (any term for state passing). They return a list of `{value, attributes}` observations. On BEAM, closures naturally capture state, and `callback_args` provides an additional explicit mechanism per spec SHOULD.

For multi-instrument callbacks, `Meter.register_callback/5` accepts a list of instruments and a callback. The callback returns `[{instrument_name, [{value, attributes}]}]` tagged tuples to distinguish which instrument each observation belongs to.

### Callback Execution

Callback evaluation is an SDK responsibility. The API layer only handles registration. The SDK evaluates each registered callback exactly once per collection cycle, reports observations with identical timestamps, and handles MetricReader independence.

### No Recording Functions

Unlike synchronous instruments, async instruments have no `add` or `record` functions. Observations are produced exclusively through callbacks invoked by the SDK during collection.

### Instrument Modules

| Module | Semantics | Value |
|---|---|---|
| `Otel.API.Metrics.ObservableCounter` | Monotonically increasing absolute value | non-negative |
| `Otel.API.Metrics.ObservableGauge` | Non-additive point-in-time value | any |
| `Otel.API.Metrics.ObservableUpDownCounter` | Additive absolute value (can increase/decrease) | any |

### No-op Behavior

Without SDK: creation returns `:ok`, `register_callback` returns `:ok`. Callbacks are never invoked.

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
