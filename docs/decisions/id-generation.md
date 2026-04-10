# ID Generation

## Question

How to generate trace IDs and span IDs on BEAM? Which random source to use and how to support custom generators?

## Decision

### Behaviour + Default Implementation

Same pattern as opentelemetry-erlang: define a behaviour with two callbacks, and provide a default implementation using `rand:uniform`.

### Callbacks

| Callback | Return type | Description |
|---|---|---|
| `generate_trace_id/0` | `non_neg_integer()` | 128-bit random integer |
| `generate_span_id/0` | `non_neg_integer()` | 64-bit random integer |

### Default Implementation

`Otel.SDK.Trace.IdGenerator.Default` generates random IDs using Erlang's `:rand.uniform/1`. IDs are non-zero positive integers.

- trace_id: `rand:uniform(2^128 - 1)` — 128-bit
- span_id: `rand:uniform(2^64 - 1)` — 64-bit

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

- [Trace SDK](../compliance/trace-sdk.md)
  * Id Generators — L880, L882, L887, L899
