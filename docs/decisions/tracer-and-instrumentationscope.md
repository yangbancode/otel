# Tracer & InstrumentationScope

## Question

How to represent Tracer and InstrumentationScope on BEAM? Lightweight struct or process-backed?

## Decision

### Tracer

A `{module, config}` tuple, same as opentelemetry-erlang. The module implements the `Otel.API.Trace.Tracer` behaviour (start_span, enabled?). Lightweight — no process backing.

### InstrumentationScope

A simple struct with name, version, schema_url, and attributes (since spec v1.13.0). Identifies the instrumentation library that produced telemetry.

### Modules

- `Otel.API.Trace.Tracer` — behaviour definition
- `Otel.API.InstrumentationScope` — struct (shared across signals)
- `Otel.API.Trace.Tracer.Noop` — no-op tracer implementation

## Compliance

- [Trace API](../compliance.md)
  * Tracer — L193, L197
- [Trace SDK](../compliance.md)
  * TracerProvider — Tracer Creation — L95, L98, L100
