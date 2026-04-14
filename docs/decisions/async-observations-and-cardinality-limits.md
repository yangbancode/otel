# Async Observations & Cardinality Limits

## Question

How to handle asynchronous callback execution rules and cardinality overflow on BEAM? How to enforce limits while ensuring no measurement is lost?

## Decision

### Callback Storage

`callbacks_tab` ETS (bag, public) added to MeterProvider. Each entry:
`{instrument_key, ref, callback, callback_args, instrument}`.

Inline callbacks from `create_observable_*` with 5 args are stored
at creation time. Multi-instrument callbacks from `register_callback`
store one entry per instrument, sharing the same ref.

### Callback Registration and Unregistration

`register_callback/5` returns `{ref, callbacks_tab}` — a handle
for unregistration. `unregister_callback/1` uses `match_delete` to
remove all entries with the matching ref. API callback spec changed
from `:: :ok` to `:: term()` to support this.

### Callback Execution

`Meter.run_callbacks/1` is called during metric collection:
1. Groups callbacks by `{ref, callback, callback_args}` to avoid
   duplicate invocation of the same function
2. Invokes each callback once: `callback.(callback_args)`
3. Each callback returns `[{value, attributes}]` observations
4. Observations are aggregated through the stream pipeline
   (same as synchronous `record()`)

### Cardinality Limits

Default limit: 2000 per stream (resolved in `Stream.resolve/1`).
Configurable via View's `aggregation_cardinality_limit`.

Enforcement in `record()` via `maybe_overflow/3`:
1. If key already exists in metrics_tab → no limit check needed
2. If key is new → count existing keys for this stream
3. If count >= limit → route to overflow key with attributes
   `%{:"otel.metric.overflow" => true}`
4. Existing attribute sets continue aggregating normally

This ensures every measurement is reflected in exactly one
aggregator (spec L856) and no measurement is dropped (spec L861).

### Deferred

- Per-reader callback invocation (MetricReader Decision)
- Callback timeout (SHOULD, MetricReader Decision)
- Disregard async API usage outside callbacks (SHOULD)
- Previously-observed attribute set cleanup (SHOULD)
- Async cardinality first-observed preference (SHOULD)

### Modules

No new modules. Changes to existing:

| Module | Changes |
|---|---|
| `Otel.SDK.Metrics.MeterProvider` | Added `callbacks_tab` ETS |
| `Otel.SDK.Metrics.Meter` | Callback storage/execution, cardinality enforcement, `unregister_callback/1`, `run_callbacks/1` |
| `Otel.SDK.Metrics.Stream` | Default cardinality limit 2000 in `resolve/1` |
| `Otel.API.Metrics.Meter` | `register_callback` return type `:: term()` |

## Compliance

- [Metrics SDK](../compliance.md)
  * Observations Inside Asynchronous Callbacks (Stable) — L762, L767, L770, L773, L776
  * Cardinality Limits (Stable) — L809, L813, L823, L826, L827, L837, L840, L846, L856, L861, L866
