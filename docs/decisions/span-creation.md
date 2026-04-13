# Span Creation

## Question

How does the Trace API create spans? How to determine parent from context, handle root span option, and pass creation attributes?

## Decision

### Creation API

Spans are created only through `Otel.API.Trace.start_span/3,4` and `with_span/4,5`. These are convenience functions on the Trace module that delegate to the Tracer behaviour's `start_span/4` callback.

Two variants for each:
- `start_span(tracer, name, opts)` / `with_span(tracer, name, opts, fun)` — uses implicit (process) context
- `start_span(ctx, tracer, name, opts)` / `with_span(ctx, tracer, name, opts, fun)` — uses explicit context

### Start Options

| Option | Default | Description |
|---|---|---|
| `:attributes` | `%{}` | Initial span attributes (preferred over set_attribute later) |
| `:links` | `[]` | Links to other spans |
| `:kind` | `:internal` | SpanKind: `:internal`, `:server`, `:client`, `:producer`, `:consumer` |
| `:start_time` | current time | Custom start timestamp (nanoseconds) |
| `:is_root` | `false` | If true, ignore parent and create root span |

### Parent Determination

1. If `:is_root` is true → new trace (new trace_id)
2. Otherwise, extract span from context → that span's SpanContext is the parent
3. If no span in context → root span

### `with_span` Convenience

`with_span/3,4` starts a span, sets it as current in context, runs a function, then ends the span. Handles exceptions by recording them and re-raising.

### Module

Functions added to `Otel.API.Trace` (public entry point).

## Compliance

- [Trace API](../compliance.md)
  * Span Creation — L380, L382, L387, L390, L393, L395, L403, L408, L410, L416, L417, L418, L419, L426
  * Specifying Links — L444
