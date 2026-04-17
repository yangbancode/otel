# Otel

Pure Elixir implementation of [OpenTelemetry](https://opentelemetry.io/).

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
  - Traces
  - Metrics
  - Logs
  - Baggage
  - W3C TraceContext Propagator
  - W3C Baggage Propagator
- **Exporters**
  - Console (stdout)
  - OTLP HTTP
  - OTLP gRPC
- **Semantic Conventions**
  - Auto-generated constants (stable only)
- **Integrations**
  - Erlang `:logger` bridge
