[![Hex.pm](https://img.shields.io/hexpm/v/otel.svg)](https://hex.pm/packages/otel)
[![HexDocs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/otel)
[![CI](https://github.com/yangbancode/otel/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/yangbancode/otel/actions/workflows/ci.yml)
[![E2E](https://github.com/yangbancode/otel/actions/workflows/e2e.yml/badge.svg?branch=main)](https://github.com/yangbancode/otel/actions/workflows/e2e.yml)
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
  - OTLP HTTP
- **Configuration**
  - `Application` env only — bridge `OTEL_*` from `runtime.exs` (Phoenix pattern)
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
| W3C Trace Context | Level 2 (REC) |
| W3C Baggage | wire format per OTel's Stable Baggage Propagator |

## Installation

Add `:otel` to `deps` in `mix.exs`:

```elixir
def deps do
  [
    {:otel, "~> 0.2.0"}
  ]
end
```

## Configuration

- [Otel SDK](docs/configuration.md) — pillars, exporters, processors, propagators.
- [`:logger` bridge](docs/logger-handler.md) — Elixir log events → OTel Logs.

## How-to

- [Trace](docs/trace.md) — span lifecycle, attributes, events, status, exceptions.
- [Log](docs/log.md) — `:logger` bridge and SDK API.
- [Metrics](docs/metrics.md) — synchronous and observable instruments.

## E2E

- [E2E Test Scenarios](docs/e2e.md) — tracking matrix for end-to-end coverage against Grafana LGTM.

## License

Released under the [MIT License](LICENSE).
