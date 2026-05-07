[![Hex.pm](https://img.shields.io/hexpm/v/otel.svg)](https://hex.pm/packages/otel)
[![HexDocs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/otel)
[![CI](https://github.com/yangbancode/otel/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/yangbancode/otel/actions/workflows/ci.yml)
[![E2E](https://github.com/yangbancode/otel/actions/workflows/e2e.yml/badge.svg?branch=main)](https://github.com/yangbancode/otel/actions/workflows/e2e.yml)
[![Coverage Status](https://coveralls.io/repos/github/yangbancode/otel/badge.svg?branch=main)](https://coveralls.io/github/yangbancode/otel?branch=main)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

# Otel

Pure Elixir, [OpenTelemetry](https://opentelemetry.io/)-compatible

## Features

- **Signals**
  - Traces
  - Metrics
  - Logs
- **Propagators**
  - W3C TraceContext
  - W3C Baggage
- **Exporters**
  - OTLP/HTTP (Protobuf)
- **Integrations**
  - `:logger` bridge
  - `:telemetry` bridge

## Requirements

- Elixir `~> 1.18`
- Erlang/OTP `~> 26.2`

## Compatibility

| Component | Version |
|---|---|
| OpenTelemetry Specification | `v1.55.0` (Stable signals only) |
| OpenTelemetry Protocol (OTLP) | `v1.10.0` |
| W3C Trace Context | Level 2 (REC) |
| W3C Baggage | OTel Stable Baggage Propagator wire format |

## Installation

Add `:otel` to `deps` in `mix.exs`:

```elixir
def deps do
  [
    {:otel, "~> 0.3.0"}
  ]
end
```

## Configuration

### SDK

```elixir
# config/config.exs
config :otel, otp_app: :my_app, req_options: []
```

`:req_options` is forwarded to `Req.new/1` — see [`:req`](https://hexdocs.pm/req) for the full option list (base URL, headers, auth, retry, TLS).

### Logs

```elixir
# config/config.exs
config :kernel,
  logger: [
    {:handler, :otel, Otel.LoggerHandler, %{}}
  ]
```

`Otel.LoggerHandler` bridges Erlang's `:logger` to OpenTelemetry Logs — see [`:logger`](https://www.erlang.org/doc/apps/kernel/logger.html) for level / metadata conventions.

### Metrics

```elixir
# lib/my_app/application.ex
children = [
  {Otel.TelemetryReporter, metrics: []}
]
```

`Otel.TelemetryReporter` is a `Telemetry.Metrics` reporter — see [`:telemetry_metrics`](https://hexdocs.pm/telemetry_metrics) for how to define metrics.

### Trace

```elixir
# lib/my_app/application.ex
children = [
  {Otel.TelemetryTracer, events: []}
]
```

`Otel.TelemetryTracer` bridges `:telemetry.span/3` events to OpenTelemetry Spans — see [`:telemetry`](https://hexdocs.pm/telemetry) for how to instrument your code.

## License

Released under the [MIT License](LICENSE).
