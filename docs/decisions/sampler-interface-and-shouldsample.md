# Sampler Interface & ShouldSample

## Question

How to define the Sampler behaviour on BEAM? What is the ShouldSample callback signature and SamplingResult structure?

## Decision

### Behaviour

Same pattern as opentelemetry-erlang's `otel_sampler`: three callbacks.

| Callback | Description |
|---|---|
| `setup(opts) :: config` | Initialize sampler config from opts |
| `description(config) :: String.t()` | Human-readable sampler description |
| `should_sample(ctx, trace_id, links, name, kind, attributes, config) :: sampling_result()` | Sampling decision |

### SamplingResult

A 3-tuple `{decision, attributes, tracestate}`:

| Field | Type | Description |
|---|---|---|
| `decision` | `:drop \| :record_only \| :record_and_sample` | Sampling decision |
| `attributes` | `map()` | Additional span attributes from sampler |
| `tracestate` | `Otel.API.Trace.TraceState.t()` | Tracestate for the new SpanContext |

### Sampler Creation

`new/1` takes a sampler spec and returns `{module, description, config}`:

```elixir
sampler = Otel.SDK.Trace.Sampler.new({Otel.SDK.Trace.Sampler.AlwaysOn, %{}})
```

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Trace.Sampler` | `apps/otel_sdk/lib/otel/sdk/trace/sampler.ex` | Behaviour + dispatch |

## Compliance

- [Trace SDK](../compliance/trace-sdk.md)
  * Sampling — L304, L305, L310, L311, L320
  * Sampler — ShouldSample — L380, L398, L399, L405
  * Sampler — GetDescription — L416
