# Console Log Exporter

## Question

How to implement a console (stdout) LogRecordExporter for debugging? Output format, pairing with SimpleLogRecordProcessor?

## Decision

### Module

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Logs.Exporter.Console` | `apps/otel_sdk/lib/otel/sdk/logs/exporter/console.ex` | stdout exporter |

### Output Format

Human-readable, not standardized. Includes severity, scope, body, attributes, and trace context (when present):

```
[otel] INFO scope=my_lib trace=0af7...319c span=b7ad...3331 body="Hello" attributes=%{key: "val"}
```

### Design

Mirrors `Otel.SDK.Trace.Exporter.Console` and `Otel.SDK.Metrics.Exporter.Console` patterns. Implements `LogRecordExporter` behaviour. SHOULD be paired with `SimpleProcessor`.

## Compliance

- [Logs Exporters](../compliance.md)
  * Console (stdout) — L13, L33
