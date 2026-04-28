[![CI](https://github.com/yangbancode/otel/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/yangbancode/otel/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/yangbancode/otel/badge.svg?branch=main)](https://coveralls.io/github/yangbancode/otel?branch=main)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

# Otel

Pure Elixir implementation of [OpenTelemetry](https://opentelemetry.io/)

## Features

- **Signals**
  - Traces
  - Metrics
  - Logs
  - Baggage
- **Propagators**
  - W3C TraceContext
  - W3C Baggage
- **Exporters**
  - Console (stdout)
  - OTLP HTTP
- **Configuration**
  - Declarative YAML (`OTEL_CONFIG_FILE`)
  - Environment variables (`OTEL_*`)
  - Programmatic (`Application` env)
- **Semantic Conventions**
  - Attribute registry
  - Metric registry
- **Integrations**
  - `:logger` bridge

## Requirements

- Elixir `~> 1.18`
- Erlang/OTP `~> 26.2`

## Compatibility

| Component | Version |
|---|---|
| OpenTelemetry Specification | `v1.55.0` (Stable signals only) |
| OpenTelemetry Protocol (OTLP) | `v1.10.0` |
| OpenTelemetry Configuration | `v1.0.0` |
| OpenTelemetry Semantic Conventions | `v1.40.0` |
| W3C Trace Context | Level 2 (REC) |
| W3C Baggage | wire format per OTel's Stable Baggage Propagator |

## Installation

Add `:otel` to `deps` in `mix.exs`:

```elixir
def deps do
  [
    {:otel, "~> 0.1.0"}
  ]
end
```

## Configuration

Two independent pieces:

- **Otel SDK** — pillars, exporters, processors, propagators.
  See [Configuration](docs/configuration.md).
- **`:logger` bridge** — Elixir log events → OTel Logs.
  See [Logger Handler](docs/logger-handler.md).

## How-to

- [Trace](docs/trace.md) — span lifecycle, attributes, events, status, exceptions.
- [Log](docs/log.md) — `:logger` bridge and SDK API.
- [Metrics](docs/metrics.md) — synchronous and observable instruments.

## License

Released under the [MIT License](LICENSE).
