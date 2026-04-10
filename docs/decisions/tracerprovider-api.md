# TracerProvider API

## Question

How to implement the TracerProvider API (global registration, get-tracer) on BEAM? How to handle no-op provider when SDK is not installed?

## Decision

### Global Registration

Use `persistent_term` for global TracerProvider storage, same as opentelemetry-erlang. Fast read access, shared across all processes.

### Tracer Representation

A Tracer is a `{module, config}` tuple. The module implements the tracer callbacks (start_span, etc.). Without SDK installed, the default is `{Otel.API.Trace.Tracer.Noop, []}`.

### Get a Tracer

`get_tracer/1,2,3,4` accepts name (required), version (optional), schema_url (optional), attributes (optional, since spec v1.13.0). Returns a Tracer tuple. Invalid name (nil or empty) returns a working Tracer with empty name and logs a warning.

Tracers are cached in `persistent_term` keyed by `{provider, {name, version, schema_url}}`.

### No-op Behavior

When no SDK is installed:
- `get_tracer` returns the noop tracer
- Span creation returns the parent SpanContext from context, or an invalid SpanContext if no parent
- All operations are safe no-ops

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.API.Trace` | `apps/otel_api/lib/otel/api/trace.ex` | Public API entry point, global provider, context interaction |
| `Otel.API.Trace.TracerProvider` | `apps/otel_api/lib/otel/api/trace/tracer_provider.ex` | TracerProvider behaviour |
| `Otel.API.Trace.Tracer` | `apps/otel_api/lib/otel/api/trace/tracer.ex` | Tracer behaviour |
| `Otel.API.Trace.Tracer.Noop` | `apps/otel_api/lib/otel/api/trace/tracer/noop.ex` | No-op tracer implementation |
| `Otel.API.Trace.InstrumentationScope` | `apps/otel_api/lib/otel/api/trace/instrumentation_scope.ex` | Scope struct |

## Compliance

- [Trace API](../compliance/trace-api.md)
  * TracerProvider — L96, L104, L109
  * Get a Tracer — L115, L117, L126, L128, L129, L139, L146
  * Tracer — L193, L197
  * Enabled — L209, L212
