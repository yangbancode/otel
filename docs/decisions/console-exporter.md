# Console Exporter

## Question

How to implement the console exporter for development/debugging? Outputs to stdout.

## Decision

### Output format

Unspecified per spec — implementation-specific. Uses `IO.puts` with
custom formatting for human-readable output. Not intended for production use.

### SpanExporter behaviour

Implements `Otel.SDK.Trace.SpanExporter`:

| Callback | Behaviour |
|---|---|
| `init(config)` | Returns `{:ok, config}` |
| `export(spans, resource, state)` | Prints each span to stdout via `IO.puts` |
| `shutdown(state)` | No-op, returns `:ok` |

### Module: `Otel.SDK.Trace.Exporter.Console`

Location: `apps/otel_sdk/lib/otel/sdk/trace/exporter/console.ex`

Lives inside `otel_sdk` app (no separate app needed).

## Compliance

- [Trace Exporters](../compliance/trace-exporters.md)
  * Console (stdout) — L14, L34
