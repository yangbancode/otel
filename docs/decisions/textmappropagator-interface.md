# TextMapPropagator Interface

## Question

How to define the TextMapPropagator behaviour and carrier abstraction on BEAM?

## Decision

### Behaviour: `Otel.API.Propagator.TextMap`

Location: `apps/otel_api/lib/otel/api/propagator/text_map.ex`

Defines three callbacks:

| Callback | Description |
|---|---|
| `inject(ctx, carrier, setter)` | Injects values from context into carrier |
| `extract(ctx, carrier, getter)` | Extracts values from carrier into new context |
| `fields()` | Returns list of header keys the propagator uses |

### Carrier Abstraction

Carriers are accessed through getter and setter functions, not directly. This allows any data structure (HTTP headers, maps, etc.) to be used as a carrier.

| Type | Signature |
|---|---|
| `getter` | `(carrier, key) -> value \| nil` |
| `setter` | `(key, value, carrier) -> carrier` |

Default implementations for `[{String.t(), String.t()}]` carriers:
- `default_getter/2` — case-insensitive key lookup
- `default_setter/3` — case-insensitive key replacement
- `default_keys/1` — returns all carrier keys

### Convenience Functions

The module provides `inject/3` and `extract/3` convenience functions that read the global propagator and dispatch. Without a registered propagator, these are no-ops.

### Dispatch for Tuple Propagators

When a propagator is stored as `{module, opts}` (e.g., Composite), dispatch calls the 4-arity version `module.inject(opts, ctx, carrier, setter)` passing opts as first argument.

## Compliance

- [API Propagators](../compliance.md)
  * Operations — L83, L84, L93, L102, L102
  * TextMap Propagator — L122, L130, L183, L209, L223, L230, L240, L241, L242, L249
