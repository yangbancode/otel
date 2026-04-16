# Declarative Configuration

## Question

How to support declarative configuration via `config.exs` / `runtime.exs` so users can set up the SDK without writing provider startup code? How does opentelemetry-erlang do it, and what should our approach be?

## Decision

TBD — design documented below for implementation.

## Background: opentelemetry-erlang Pattern

opentelemetry-erlang supports fully declarative configuration:

```elixir
# config/runtime.exs
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp,
  sampler: {:parent_based, %{root: :always_on}},
  resource: %{service: %{name: "my-service"}},
  attribute_count_limit: 256

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://localhost:4318"
```

The `opentelemetry` Application `start/2` reads these values, merges with OS environment variables (env vars take priority), and automatically starts TracerProvider, processors, exporters, and resource detectors. Users write zero startup code.

## Proposed Design

### User-Facing Configuration

```elixir
# config/runtime.exs
config :otel_sdk,
  service_name: "my_app",
  service_version: "1.0.0",

  # Traces
  traces_exporter: :otlp,
  traces_processor: :batch,
  sampler: {:parent_based, %{root: :always_on}},

  # Metrics
  metrics_exporter: :otlp,
  metrics_reader: :periodic,

  # Logs
  logs_exporter: :otlp,
  logs_processor: :batch,
  logger_handler: true

config :otel_exporter_otlp,
  endpoint: "http://localhost:4318",
  compression: :gzip,
  headers: %{"Authorization" => "Bearer token"}
```

### Shorthand Expansion

| Shorthand | Expands To |
|---|---|
| `traces_exporter: :otlp` | `{Otel.Exporter.OTLP.Traces, %{}}` |
| `traces_exporter: :console` | `{Otel.SDK.Trace.Exporter.Console, %{}}` |
| `traces_exporter: :none` | disabled |
| `traces_processor: :batch` | `{Otel.SDK.Trace.BatchProcessor, defaults}` |
| `traces_processor: :simple` | `{Otel.SDK.Trace.SimpleProcessor, defaults}` |
| `logs_exporter: :otlp` | `{Otel.Exporter.OTLP.Logs, %{}}` |
| `logs_processor: :batch` | `{Otel.SDK.Logs.BatchProcessor, defaults}` |
| `metrics_exporter: :otlp` | `{Otel.Exporter.OTLP.Metrics, %{}}` |
| `metrics_reader: :periodic` | `{Otel.SDK.Metrics.PeriodicExportingMetricReader, defaults}` |
| `logger_handler: true` | registers `Otel.Logger.Handler` with `:logger` |

### Priority Order

```
OS environment variables (OTEL_*)
  > config/runtime.exs
    > config/config.exs
      > SDK defaults
```

This matches the OTel spec requirement and the opentelemetry-erlang precedence.

### Implementation: Otel.SDK.Application

`Otel.SDK.Application.start/2` reads the merged config and starts all providers:

```elixir
defmodule Otel.SDK.Application do
  use Application

  def start(_type, _args) do
    config = build_config()

    children =
      []
      |> maybe_add_trace_pipeline(config)
      |> maybe_add_metrics_pipeline(config)
      |> maybe_add_logs_pipeline(config)

    opts = [strategy: :one_for_one, name: Otel.SDK.Supervisor]
    result = Supervisor.start_link(children, opts)

    maybe_register_logger_handler(config)
    result
  end
end
```

### What This Means for Users

**Before (current — imperative):**

```elixir
defmodule MyApp.Application do
  def start(_type, _args) do
    # 30+ lines of OTel setup code
    {:ok, _} = Otel.SDK.Trace.BatchProcessor.start_link(...)
    {:ok, _} = Otel.SDK.Trace.TracerProvider.start_link(...)
    {:ok, _} = Otel.SDK.Metrics.MeterProvider.start_link(...)
    {:ok, _} = Otel.SDK.Logs.BatchProcessor.start_link(...)
    {:ok, _} = Otel.SDK.Logs.LoggerProvider.start_link(...)
    :logger.add_handler(...)
    # ... then start your app ...
  end
end
```

**After (declarative):**

```elixir
# config/runtime.exs
config :otel_sdk,
  service_name: "my_app",
  traces_exporter: :otlp,
  metrics_exporter: :otlp,
  logs_exporter: :otlp,
  logger_handler: true

# mix.exs — just add the dependency, no startup code needed
{:otel_sdk, "~> 0.2.0"}
```

### Scope

| Item | Description |
|---|---|
| Config reader | Reads `Application.get_all_env(:otel_sdk)` + OS env vars |
| Shorthand expansion | Maps atoms to `{module, opts}` tuples |
| Auto-start | Starts providers, processors, exporters under `Otel.SDK.Supervisor` |
| :logger handler | Optionally registers handler when `logger_handler: true` |
| Shutdown | Supervisor handles graceful shutdown of all children |

### Dependencies on Other Work

- Requires `Otel.SDK.Application` to be the entry point (currently exists but minimal)
- Should be implemented alongside or after hex.pm publishing
- Imperative API (current) remains available for advanced users

## Compliance

No direct spec compliance items — configuration mechanism is implementation-specific.
