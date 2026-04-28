# Otel

[![CI](https://github.com/yangbancode/otel/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/yangbancode/otel/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/yangbancode/otel/badge.svg?branch=main)](https://coveralls.io/github/yangbancode/otel?branch=main)

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
| [`otel_otlp`](apps/otel_otlp) | Pure Elixir implementation of the OpenTelemetry Protocol (OTLP), currently with the HTTP transport exporter |
| [`otel_logger_handler`](apps/otel_logger_handler) | Pure Elixir implementation of an OpenTelemetry Logs handler for `:logger` |
| [`otel_config`](apps/otel_config) | Declarative configuration loader for `OTEL_CONFIG_FILE` (YAML) — opt-in |
