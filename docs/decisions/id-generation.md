# ID Generation

## Question

How to generate trace IDs and span IDs on BEAM? Which random source to use and how to support custom generators?

## Decision

### Behaviour + Default Implementation

Define a behaviour with two callbacks returning Spec-First Type System structs, and provide a default implementation backed by `:crypto.strong_rand_bytes/1`.

### Callbacks

| Callback | Return type | Description |
|---|---|---|
| `generate_trace_id/0` | `Otel.API.Trace.TraceId.t()` | 16-byte random TraceId |
| `generate_span_id/0` | `Otel.API.Trace.SpanId.t()` | 8-byte random SpanId |

### Default Implementation

`Otel.SDK.Trace.IdGenerator.Default` generates random IDs using `:crypto.strong_rand_bytes/1` and wraps the bytes in the opaque TraceId/SpanId structs. Zero-value IDs are invalid, so the generator re-rolls until a non-zero result is obtained.

- trace_id: `:crypto.strong_rand_bytes(16)` with zero-reroll, wrapped as `TraceId.t()`
- span_id: `:crypto.strong_rand_bytes(8)` with zero-reroll, wrapped as `SpanId.t()`

### Custom Generators

Users can provide a custom module implementing the behaviour via TracerProvider config:

```elixir
Otel.SDK.Trace.TracerProvider.start_link(
  config: %{id_generator: MyCustomIdGenerator}
)
```

Vendor-specific generators (AWS X-Ray, etc.) MUST NOT be part of this repository (L899).

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Trace.IdGenerator` | `apps/otel_sdk/lib/otel/sdk/trace/id_generator.ex` | Behaviour definition |
| `Otel.SDK.Trace.IdGenerator.Default` | `apps/otel_sdk/lib/otel/sdk/trace/id_generator/default.ex` | Default random implementation |

## Compliance

- [Trace SDK](../compliance.md)
  * Id Generators — L880, L882, L887, L899
