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
    {:otel, "~> 0.4.1"}
  ]
end
```

## Configuration

### SDK

```elixir
# config/config.exs
config :otel, otp_app: :my_app, req_options: []
```

`:req_options` is forwarded to `Req.new/1` — see [`:req`](https://hexdocs.pm/req) for the full option list.

### Logs

```elixir
# config/config.exs
config :kernel,
  logger: [
    {:handler, :otel, Otel.LoggerHandler, %{}}
  ]
```

`Otel.LoggerHandler` bridges `Logger` — see [`:logger`](https://www.erlang.org/doc/apps/kernel/logger.html) for log levels and metadata.

### Metrics

```elixir
# lib/my_app/application.ex
children = [
  {Otel.TelemetryReporter, metrics: []}
]
```

`Otel.TelemetryReporter` bridges `Telemetry.Metrics` — see [`:telemetry_metrics`](https://hexdocs.pm/telemetry_metrics) for metric definitions.

### Trace

```elixir
# lib/my_app/application.ex
children = [
  {Otel.TelemetryTracer, events: []}
]
```

`Otel.TelemetryTracer` bridges `:telemetry.span/3` — see [`:telemetry`](https://hexdocs.pm/telemetry) for instrumentation.

#### Optional: `Otel.TelemetrySpanDecorator`

```elixir
# lib/my_app.ex
defmodule MyApp do
  use Otel.TelemetrySpanDecorator

  @span [:my_app, :hello]
  # @span event: [:my_app, :hello], capture_io: true
  def hello, do: :world
end
```

`@span` auto-wraps the function body in `:telemetry.span/3` and injects `code.function.name` / `code.file.path` / `code.line.number`; pass `capture_io: true` to also record arguments and the return value.

## How-to

End-to-end example wiring traces, logs, and metrics for a `MyApp.Calculator` module.

```elixir
# config/config.exs
import Config

config :otel, otp_app: :my_app

config :kernel,
  logger: [
    {:handler, :otel, Otel.LoggerHandler, %{}}
  ]
```

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  import Telemetry.Metrics

  @impl true
  def start(_type, _args) do
    children = [
      {Otel.TelemetryTracer,
       events: [
         [:my_app, :calculator, :add]
       ]},
      {Otel.TelemetryReporter,
       metrics: [
         counter("my_app.calculator.add.count",
           event_name: [:my_app, :calculator, :add, :stop],
           measurement: :duration
         ),
         distribution("my_app.calculator.add.duration",
           event_name: [:my_app, :calculator, :add, :stop],
           measurement: :duration,
           unit: {:native, :millisecond},
           reporter_options: [buckets: [10, 50, 100, 500]]
         ),
         summary("my_app.calculator.add.duration_summary",
           event_name: [:my_app, :calculator, :add, :stop],
           measurement: :duration,
           unit: {:native, :millisecond}
         )
       ]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

```elixir
# lib/my_app/calculator.ex
defmodule MyApp.Calculator do
  use Otel.TelemetrySpanDecorator
  require Logger

  @span event: [:my_app, :calculator, :add], capture_io: true
  def add(a, b) do
    Logger.info("calculator.add", a: a, b: b)
    a + b
  end
end
```

## License

Released under the [MIT License](LICENSE).
