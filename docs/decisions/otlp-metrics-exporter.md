# OTLP Metrics Exporter

## Question

How to implement OTLP export for metrics, reusing the existing OTLP HTTP transport and Protobuf encoding from the Trace exporter?

## Decision

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.Exporter.OTLP.Metrics` | `apps/otel_exporter_otlp/lib/otel/exporter/otlp/metrics.ex` | MetricExporter — HTTP POST to OTLP endpoint |
| `Otel.Exporter.OTLP.Encoder` | `apps/otel_exporter_otlp/lib/otel/exporter/otlp/encoder.ex` | Extended with `encode_metrics/1` — SDK metric → Protobuf binary |

### Architecture

Mirrors the Traces exporter pattern exactly. Both share the same `Encoder` module for attribute/resource/scope encoding.

### Configuration

| Option | Default | Description |
|---|---|---|
| `endpoint` | `http://localhost:4318` | Base URL (appends `/v1/metrics`) |
| `headers` | `%{}` | Custom HTTP headers |
| `compression` | `:none` | `:gzip` or `:none` |
| `timeout` | `10_000` ms | HTTP request timeout |

### Environment Variables

Signal-specific env > general env > code config > defaults.

| Signal-specific | General |
|---|---|
| `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` | `OTEL_EXPORTER_OTLP_ENDPOINT` |
| `OTEL_EXPORTER_OTLP_METRICS_HEADERS` | `OTEL_EXPORTER_OTLP_HEADERS` |
| `OTEL_EXPORTER_OTLP_METRICS_COMPRESSION` | `OTEL_EXPORTER_OTLP_COMPRESSION` |
| `OTEL_EXPORTER_OTLP_METRICS_TIMEOUT` | `OTEL_EXPORTER_OTLP_TIMEOUT` |

### Encoding Flow

```
MetricReader.metric() → Encoder.encode_metrics/1 → ExportMetricsServiceRequest protobuf binary
  → optional gzip → HTTP POST with Content-Type: application/x-protobuf
```

### Metric Type Mapping

| SDK Instrument Kind | Protobuf Data Type |
|---|---|
| `:counter`, `:updown_counter`, `:observable_counter`, `:observable_updown_counter` | `Sum` with `NumberDataPoint` |
| `:gauge`, `:observable_gauge` | `Gauge` with `NumberDataPoint` |
| `:histogram` | `Histogram` with `HistogramDataPoint` |

### Protobuf Code Generation

Generated from `references/opentelemetry-proto` using `protoc` with `protoc-gen-elixir`:

```bash
protoc \
  --proto_path=references/opentelemetry-proto \
  --elixir_out=apps/otel_exporter_otlp/lib/otel/exporter/otlp/proto \
  opentelemetry/proto/metrics/v1/metrics.proto \
  opentelemetry/proto/collector/metrics/v1/metrics_service.proto
```

## Compliance

- [Metrics SDK](../compliance.md)
  * MetricExporter (Stable) — L1496
  * Push Metric Exporter — L1557, L1565, L1571
