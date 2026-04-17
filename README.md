# Otel

Pure Elixir implementation of [OpenTelemetry](https://opentelemetry.io/)

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
  - [ ] OTLP gRPC
- **Semantic Conventions**
  - Attributes
  - Metrics
- **Integrations**
  - `:logger` bridge

## Packages

| App | Description |
|---|---|
| [`otel_api`](apps/otel_api) | Pure Elixir implementation of the OpenTelemetry API |
| [`otel_sdk`](apps/otel_sdk) | Pure Elixir implementation of the OpenTelemetry SDK |
| [`otel_semantic_conventions`](apps/otel_semantic_conventions) | Pure Elixir implementation of OpenTelemetry Semantic Conventions |
| [`otel_exporter_otlp`](apps/otel_exporter_otlp) | Pure Elixir implementation of the OpenTelemetry Protocol (OTLP) exporter |
| [`otel_logger_handler`](apps/otel_logger_handler) | Pure Elixir implementation of an OpenTelemetry Logs handler for `:logger` |
