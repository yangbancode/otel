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

## Quick Example

### Trace

```elixir
scope = %Otel.API.InstrumentationScope{name: "my_app", version: "1.0.0"}
tracer = Otel.API.Trace.TracerProvider.get_tracer(scope)

Otel.API.Trace.with_span(tracer, "checkout", [kind: :server], fn span_ctx ->
  Otel.API.Trace.Span.set_attribute(span_ctx, "user.id", 42)
  Otel.API.Trace.Span.add_event(span_ctx, "cart.validated")
  process_order()
end)
```

### Log

Via Elixir's `:logger` bridge:

```elixir
require Logger
Logger.info("checkout completed", user_id: 42, total: 99.95)
```

Via the SDK API:

```elixir
scope = %Otel.API.InstrumentationScope{name: "my_app", version: "1.0.0"}
logger = Otel.API.Logs.LoggerProvider.get_logger(scope)

Otel.API.Logs.Logger.emit(logger, %Otel.API.Logs.LogRecord{
  body: "checkout completed",
  severity_number: 9,
  attributes: %{"user.id" => 42}
})
```

### Metrics

```elixir
scope = %Otel.API.InstrumentationScope{name: "my_app", version: "1.0.0"}
meter = Otel.API.Metrics.MeterProvider.get_meter(scope)

counter = Otel.API.Metrics.Meter.create_counter(meter, "http.requests")
Otel.API.Metrics.Counter.add(counter, 1, %{"http.method" => "GET"})
```

## License

Released under the [MIT License](LICENSE).
