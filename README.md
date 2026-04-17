# Otel

Pure Elixir implementation of [OpenTelemetry](https://opentelemetry.io/).

> [!WARNING]
> **Status: Alpha** — Basic functionality has been tested with a real OTel Collector. API is unstable and may change without notice. Not recommended for production use.

## Features

- **Specification**
  - [x] Traces
  - [x] Metrics
  - [x] Logs
  - [x] Baggage
  - [x] W3C TraceContext Propagator
  - [x] W3C Baggage Propagator
- **Exporters**
  - [x] Console (stdout)
  - [x] OTLP HTTP
  - [ ] OTLP gRPC
- **Semantic Conventions**
  - [x] Auto-generated constants (stable only)
- **Integrations**
  - [x] Erlang `:logger` bridge

## Requirements

- Elixir 1.18+
- Erlang/OTP 26+

## Packages

| App | Description |
|---|---|
| [`otel_api`](apps/otel_api) | Instrumentation API — Tracer, Meter, Logger, Span, Baggage |
| [`otel_sdk`](apps/otel_sdk) | SDK implementation — providers, processors, samplers, resource detection |
| [`otel_semantic_conventions`](apps/otel_semantic_conventions) | Auto-generated attribute and metric key constants |
| [`otel_exporter_otlp`](apps/otel_exporter_otlp) | OTLP HTTP exporter (protobuf over HTTP/1.1) |
| [`otel_logger_handler`](apps/otel_logger_handler) | Elixir `:logger` bridge to OTel Logs |

Each app is published independently on hex.pm. Refer to the per-app README for installation and usage.

## License

Released into the public domain under the [Unlicense](LICENSE).
