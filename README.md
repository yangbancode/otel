[![CI](https://github.com/yangbancode/otel/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/yangbancode/otel/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/yangbancode/otel/badge.svg?branch=main)](https://coveralls.io/github/yangbancode/otel?branch=main)
[![License](https://img.shields.io/badge/license-Unlicense-blue.svg)](https://unlicense.org/)

# Otel

Pure Elixir implementation of [OpenTelemetry](https://opentelemetry.io/).

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
- **Semantic Conventions**
  - Attributes
  - Metrics
- **Integrations**
  - `:logger` bridge

## Requirements

- Elixir `~> 1.18`
- Erlang/OTP `~> 26.2`

## Compatibility

| Component | Version |
|---|---|
| OpenTelemetry Specification | `v1.55.0` |
| W3C Trace Context | Level 2 |
| W3C Baggage | Working Draft |
| OTLP | `v1.10.0` |

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

Configure the three signal pillars and the propagator in `config/runtime.exs`:

```elixir
import Config

config :otel,
  trace: [
    sampler: :parentbased_always_on,
    exporter: :otlp,
    processor: :batch,
    span_limits: %{attribute_count_limit: 256}
  ],
  metrics: [
    exporter: :otlp,
    export_interval_ms: 30_000
  ],
  logs: [
    exporter: :otlp,
    processor: :batch
  ],
  propagators: [:tracecontext, :baggage]
```

The SDK reads OS env vars (`OTEL_*`) too — see
[`Otel.SDK.Config`](lib/otel/sdk/config.ex) for the precedence rules
(programmatic > OS env > Application env > built-in defaults).

To bridge Elixir's `:logger` into OTel Logs, attach the handler:

```elixir
:logger.add_handler(:otel, Otel.LoggerHandler, %{
  config: %{scope_name: "my_app"}
})
```

## Example

```elixir
scope = %Otel.API.InstrumentationScope{name: "my_app", version: "1.0.0"}

# Trace — Span with auto-managed lifecycle (start, end, exception recording).
tracer = Otel.API.Trace.TracerProvider.get_tracer(scope)

Otel.API.Trace.with_span(tracer, "checkout", [kind: :server], fn span_ctx ->
  Otel.API.Trace.Span.set_attribute(span_ctx, "user.id", 42)
  Otel.API.Trace.Span.add_event(span_ctx, "cart.validated")
  process_order()
end)

# Metrics — Counter.
meter = Otel.API.Metrics.MeterProvider.get_meter(scope)
counter = Otel.API.Metrics.Meter.create_counter(meter, "http.requests")
Otel.API.Metrics.Counter.add(counter, 1, %{"http.method" => "GET"})

# Logs — structured via the :logger bridge.
require Logger
Logger.info("checkout completed", user_id: 42, total: 99.95)
```

## License

Released into the public domain under [The Unlicense](https://unlicense.org/).
