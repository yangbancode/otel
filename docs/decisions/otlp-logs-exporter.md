# OTLP Logs Exporter

## Question

How to implement OTLP export for logs, reusing the existing OTLP HTTP transport and Protobuf encoding from the Trace and Metrics exporters?

## Decision

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.Exporter.OTLP.Logs` | `apps/otel_exporter_otlp/lib/otel/exporter/otlp/logs.ex` | LogRecordExporter — HTTP POST to OTLP endpoint |
| `Otel.Exporter.OTLP.Encoder` | `apps/otel_exporter_otlp/lib/otel/exporter/otlp/encoder.ex` | Extended with `encode_logs/1` |

### Architecture

Mirrors the Traces and Metrics exporter patterns exactly. All three share the same `Encoder` module for attribute/resource/scope encoding.

### Configuration

| Option | Default | Description |
|---|---|---|
| `endpoint` | `http://localhost:4318` | Base URL (appends `/v1/logs`) |
| `headers` | `%{}` | Custom HTTP headers |
| `compression` | `:none` | `:gzip` or `:none` |
| `timeout` | `10_000` ms | HTTP request timeout |

### Environment Variables

| Signal-specific | General |
|---|---|
| `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` | `OTEL_EXPORTER_OTLP_ENDPOINT` |
| `OTEL_EXPORTER_OTLP_LOGS_HEADERS` | `OTEL_EXPORTER_OTLP_HEADERS` |
| `OTEL_EXPORTER_OTLP_LOGS_COMPRESSION` | `OTEL_EXPORTER_OTLP_COMPRESSION` |
| `OTEL_EXPORTER_OTLP_LOGS_TIMEOUT` | `OTEL_EXPORTER_OTLP_TIMEOUT` |

### Encoding Flow

```
log_record map → Encoder.encode_logs/1 → ExportLogsServiceRequest protobuf binary
  → optional gzip → HTTP POST with Content-Type: application/x-protobuf
```

### LogRecord Protobuf Mapping

| SDK Field | Proto Field |
|---|---|
| `timestamp` | `time_unix_nano` |
| `observed_timestamp` | `observed_time_unix_nano` |
| `severity_number` | `severity_number` (enum) |
| `severity_text` | `severity_text` |
| `body` | `body` (AnyValue) |
| `attributes` | `attributes` (KeyValue list) |
| `dropped_attributes_count` | `dropped_attributes_count` |
| `trace_id` | `trace_id` (16-byte binary, empty when 0) |
| `span_id` | `span_id` (8-byte binary, empty when 0) |
| `trace_flags` | `flags` |
| `event_name` | `event_name` |

### Protobuf Code Generation

```bash
protoc \
  --proto_path=references/opentelemetry-proto \
  --elixir_out=apps/otel_exporter_otlp/lib/otel/exporter/otlp/proto \
  opentelemetry/proto/logs/v1/logs.proto \
  opentelemetry/proto/collector/logs/v1/logs_service.proto
```

## Compliance

- [Logs SDK](../compliance.md)
  * LogRecordExporter — L559, L563
  * Export — L582
