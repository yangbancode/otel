# Otel

Pure Elixir implementation of [OpenTelemetry](https://opentelemetry.io/).

> [!WARNING]
> **Status: Alpha** — Basic functionality has been tested with a real OTel Collector. API is unstable and may change without notice. Not recommended for production use.

## Requirements

- Elixir 1.18+
- Erlang/OTP 26+

## Packages

| App | Description |
|---|---|
| [`otel_api`](apps/otel_api) | Instrumentation API for traces, metrics, logs, and baggage |
| [`otel_sdk`](apps/otel_sdk) | Default SDK with providers, processors, and samplers |
| [`otel_semantic_conventions`](apps/otel_semantic_conventions) | Auto-generated attribute and metric key constants |
| [`otel_exporter_otlp`](apps/otel_exporter_otlp) | OTLP HTTP exporter for traces, metrics, and logs |
| [`otel_logger_handler`](apps/otel_logger_handler) | Elixir `:logger` handler that forwards logs to OTel |

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

## License

Released into the public domain under the [Unlicense](LICENSE).
