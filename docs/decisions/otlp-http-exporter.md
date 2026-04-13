# OTLP HTTP Exporter

## Question

How to implement the OTLP HTTP exporter on BEAM? HTTP client choice, binary protobuf encoding, gzip compression, endpoint configuration, partial success handling?

## Decision

### Modules

| Module | Location | Description |
|---|---|---|
| `Otel.Exporter.OTLP.Traces` | `apps/otel_exporter_otlp/lib/otel/exporter/otlp/traces.ex` | SpanExporter — HTTP POST to OTLP endpoint |
| `Otel.Exporter.OTLP.Encoder` | `apps/otel_exporter_otlp/lib/otel/exporter/otlp/encoder.ex` | SDK Span → Protobuf binary conversion |

### HTTP Client: Erlang `:httpc`

Built-in, no extra dependency. Same approach as opentelemetry-erlang.

### Configuration

| Option | Default | Description |
|---|---|---|
| `endpoint` | `http://localhost:4318` | Base URL (appends `/v1/traces`) |
| `headers` | `%{}` | Custom HTTP headers |
| `compression` | `:none` | `:gzip` or `:none` |
| `timeout` | `10_000` ms | HTTP request timeout |

### Encoding Flow

```
SDK Span → Encoder.encode_traces/2 → ExportTraceServiceRequest protobuf binary
  → optional gzip → HTTP POST with Content-Type: application/x-protobuf
```

### Encoder Details

- Spans grouped by InstrumentationScope into ScopeSpans
- Resource attributes encoded as KeyValue list
- Attribute types: string, int, float, bool, atom→string, list→array
- trace_id encoded as 16-byte binary, span_id as 8-byte binary
- SpanKind mapped to proto enum values
- Status mapped: nil→no status, :ok→STATUS_CODE_OK, :error→STATUS_CODE_ERROR

### User-Agent

`OTel-OTLP-Exporter-Elixir/0.1.0`

## Compliance

- [OTLP Protocol](../compliance.md)
  * OTLP/HTTP — L390, L392
  * Binary Protobuf Encoding — L400
  * OTLP/HTTP Request — L454, L459, L462, L469
  * OTLP/HTTP Response — L478, L482, L484, L485
  * Full Success (HTTP) — L498, L500, L507
  * Partial Success (HTTP) — L513, L518, L525, L533, L536
  * Failures (HTTP) — L541, L545, L554, L560, L562, L566, L568
  * Bad Data (HTTP) — L580, L581, L586
  * OTLP/HTTP Throttling — L592, L597, L600
  * All Other Responses — L608
  * OTLP/HTTP Connection — L614, L618, L620
  * OTLP/HTTP Concurrent Requests — L632
  * OTLP/HTTP Default Port — L636
- [OTLP Exporter Configuration](../compliance.md)
  * Configuration Options — L13, L14, L17, L26, L71, L77, L83
  * Endpoint URLs for OTLP/HTTP — L101, L105, L115
  * User Agent — L205, L211
