# SpanExporter Interface

## Question

How to define the SpanExporter behaviour on BEAM? Export, Shutdown, ForceFlush signatures and concurrency guarantees?

## Decision

### Behaviour

Same pattern as opentelemetry-erlang's `otel_exporter_traces`:

| Callback | Parameters | Return |
|---|---|---|
| `init(config)` | exporter config | `{:ok, state} \| :ignore` |
| `export(spans, resource, state)` | span list, resource, exporter state | `:ok \| :error` |
| `shutdown(state)` | exporter state | `:ok` |

`force_flush` is not a callback on the exporter — it's the processor's responsibility to call `export` with pending spans and then `force_flush` on the exporter if needed.

### Export result

| Result | Meaning |
|---|---|
| `:ok` | Successfully exported |
| `:error` | Export failed (processor decides retry) |

### Concurrency

Export MUST NOT be called concurrently for the same exporter instance. The processor is responsible for serializing export calls.

### Module: `Otel.SDK.Trace.SpanExporter`

Location: `apps/otel_sdk/lib/otel/sdk/trace/span_exporter.ex`

## Compliance

- [Trace SDK](../compliance.md)
  * Span Exporter — Interface Definition — L1130, L1135
  * Span Exporter — Export — L1156, L1160
  * Span Exporter — ForceFlush — L1208, L1211, L1215
