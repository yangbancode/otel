# OTLP Environment Variables

## Question

How to parse and apply OTEL_EXPORTER_OTLP_* environment variables (OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_PROTOCOL, OTEL_EXPORTER_OTLP_HEADERS, etc.)?

## Decision

Each OTLP exporter reads its own environment variables directly in `init/1`, following the same pattern as BatchProcessor. No centralized Configuration module involvement.

### Priority

```
Signal-specific env var > General env var > Code config > Default
```

### Supported Variables

| Signal-specific | General | Default |
|---|---|---|
| `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318` |
| `OTEL_EXPORTER_OTLP_TRACES_HEADERS` | `OTEL_EXPORTER_OTLP_HEADERS` | none |
| `OTEL_EXPORTER_OTLP_TRACES_COMPRESSION` | `OTEL_EXPORTER_OTLP_COMPRESSION` | none |
| `OTEL_EXPORTER_OTLP_TRACES_TIMEOUT` | `OTEL_EXPORTER_OTLP_TIMEOUT` | 10000 ms |

### Endpoint Behavior

- General endpoint (`OTEL_EXPORTER_OTLP_ENDPOINT`): `/v1/traces` path appended
- Signal-specific endpoint (`OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`): used as-is (no path appended)

### Headers Format

`key1=value1,key2=value2` — comma-separated key=value pairs, per W3C Baggage format.

### Parsing Rules

- Empty values treated as unset
- Compression: only `gzip` recognized, all other values default to `none`
- Timeout: integer milliseconds, unparseable values use default

## Compliance

- [Compliance](../compliance.md)
  * OTLP Exporter Configuration — Configuration Options, Endpoint URLs, Specify Protocol
