# TracerProvider SDK: Configuration

## Question

How to implement TracerProvider SDK with full configuration (processors, sampler, id_generator, span_limits, resource) on BEAM?

## Decision

### GenServer

TracerProvider SDK is a `GenServer` that owns all configuration. Same pattern as opentelemetry-erlang's `otel_tracer_server`.

### Configuration

| Config | Type | Default |
|---|---|---|
| `sampler` | `{module, opts}` | `{Otel.SDK.Trace.Sampler.AlwaysOn, []}` |
| `processors` | `[{module, config}]` | `[]` |
| `id_generator` | `module` | `Otel.SDK.Trace.IdGenerator.Default` |
| `resource` | `Otel.SDK.Resource.t()` | empty resource |
| `span_limits` | `Otel.SDK.Trace.SpanLimits.t()` | spec defaults |

Configuration is stored in GenServer state. All tracers returned by `get_tracer` hold a reference to the provider and read configuration from it.

### Tracer Registration

When SDK starts, it registers itself as the global TracerProvider via `Otel.API.Trace.TracerProvider.set_provider/1`. This replaces the API-level Noop tracer with the SDK tracer for all subsequent `get_tracer` calls.

### Module: `Otel.SDK.Trace.TracerProvider`

Location: `apps/otel_sdk/lib/otel/sdk/trace/tracer_provider.ex`

## Compliance

- [Trace SDK](../compliance/trace-sdk.md)
  * TracerProvider — Configuration — L113, L119, L120
