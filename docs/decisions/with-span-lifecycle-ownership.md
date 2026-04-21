# with_span Lifecycle Ownership

## Question

Where should `with_span` own its lifecycle — at the API facade
(`Otel.API.Trace`), or at each Tracer implementation (Noop + SDK)?

"Lifecycle" here means: start span → `set_current_span` → `Ctx.attach`
→ run user function → (on failure: record exception + set status) →
`Ctx.detach` → end span.

## Decision

**Each Tracer implementation owns the full lifecycle.** The API module
is a thin dispatcher.

```
Otel.API.Trace.with_span/5       ← thin dispatcher
  └─ module.with_span(ctx, tracer, name, opts, fun)
      └─ Otel.API.Trace.Tracer.Noop.with_span/5      ← attach / try / detach
         or
         Otel.SDK.Trace.Tracer.with_span/5           ← attach / try-catch / detach / end
```

This mirrors `opentelemetry-erlang`:

| Layer                    | Our module                    | Erlang module                    |
|--------------------------|-------------------------------|----------------------------------|
| API dispatcher           | `Otel.API.Trace`              | `otel_tracer` (in `_api` app)    |
| API-level Noop tracer    | `Otel.API.Trace.Tracer.Noop`  | `otel_tracer_noop` (in `_api`)   |
| SDK tracer               | `Otel.SDK.Trace.Tracer`       | `otel_tracer_default` (in SDK)   |

## Rationale

### Lifecycle-ownership invariant

The operation that calls `Otel.API.Ctx.attach/1` MUST also call the
matching `detach/1` on every exit path — normal return, thrown value,
raised error, process exit. Splitting this across layers (e.g. API
does `attach`, SDK does `detach`) would create an attach/detach pair
that crosses a module boundary — a fragile invariant that relies on
both sides continuing to cooperate.

Keeping attach/detach inside one function in one module makes the
pair locally auditable: one `attach` call, one `try`, one
`detach` in `after`. No external contract to honour.

Error handling (`record_exception`, `set_status`) belongs in the same
block because it runs between attach and detach — it needs access to
the live `SpanContext` the attach owns.

### Per-Tracer customisation

`with_span` behaviour differs between Tracers:

- **Noop** doesn't store spans → `end_span` is pointless, exception
  recording is pointless. Noop's `with_span` is `start + attach +
  try/after + detach`, matching `otel_tracer_noop.erl`.
- **SDK** stores spans in ETS → must call `end_span` to release
  storage and fire `on_end` processors; records exceptions per
  `trace/exceptions.md` L14-L40.
- A future Tracer (batch-sampler, sidecar-forwarder, test fixture)
  may have yet different lifecycle needs — adding them without
  changing the API facade is cheap under the callback model.

### Spec alignment

`trace/api.md` L385 leaves `with_span` entirely as a `MAY`:
*"MAY be offered additionally as a separate operation"*. Neither the
callback model nor an API-centralised implementation is mandated.
This decision picks the model that cleanly supports multiple Tracer
implementations without leaking SDK concerns into the API layer.

## Consequences

### Module: `Otel.API.Trace.Tracer`

`@callback with_span/5` added alongside `@callback start_span/4` and
`@callback enabled?/2`.

### Module: `Otel.API.Trace`

`with_span/5` reduced to:

```elixir
def with_span(ctx, {module, _config} = tracer, name, opts, fun) do
  module.with_span(ctx, tracer, name, opts, fun)
end
```

`with_span/4` (implicit context) still injects
`Otel.API.Ctx.current()` and forwards to `/5`.

### Module: `Otel.API.Trace.Tracer.Noop`

Implements `with_span/5` with `try/after` only — no catch, no
`record_exception`, no `end_span`. Noop spans don't need ending and
have nothing to record.

### Module: `Otel.SDK.Trace.Tracer`

Implements `with_span/5` with the full `try/catch/after` block —
on `:error` records the exception and sets error status, on
`:throw` / `:exit` sets error status, then `:erlang.raise/3`
re-raises preserving the kind and stacktrace. `after` calls
`Span.end_span` and `Ctx.detach`.

### Trade-offs accepted

- **More code** than the old centralised version — two
  implementations instead of one. Mitigated by the small size of
  the Noop variant (no catch, no end).
- **`with_span/5` callback is a behaviour growth** — every future
  Tracer must implement it. Unavoidable if we want per-Tracer
  lifecycle control.

## Compliance

- [OTel Trace API §Span Creation L378-L414](../compliance.md) — span
  creation MUSTs are carried by `start_span/4`; this decision
  governs only the `MAY` at L385.
