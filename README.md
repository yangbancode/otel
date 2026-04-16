# Otel

> [!WARNING]
> **Status: Alpha** — Basic functionality has been tested with a real OTel Collector. API is unstable and may change without notice. Not recommended for production use.

Pure Elixir implementation of [OpenTelemetry](https://opentelemetry.io/).

## Features

- **Specification** — [opentelemetry-specification v1.55.0](https://github.com/open-telemetry/opentelemetry-specification/releases/tag/v1.55.0)
  - [x] Traces
  - [x] Metrics
  - [x] Logs
  - [x] Baggage
  - [x] W3C TraceContext Propagator
  - [x] W3C Baggage Propagator
- **Exporters** — [opentelemetry-proto v1.10.0](https://github.com/open-telemetry/opentelemetry-proto/releases/tag/v1.10.0)
  - [x] Console (stdout)
  - [x] OTLP HTTP
  - [ ] OTLP gRPC
- **Semantic Conventions** — [semantic-conventions v1.40.0](https://github.com/open-telemetry/semantic-conventions/releases/tag/v1.40.0)
  - [ ] Auto-generated constants
- **Integrations**
  - [x] Erlang `:logger` bridge

## Requirements

- Elixir ~> 1.19
- Erlang/OTP ~> 28

## Installation

Add the dependencies to your `mix.exs`:

```elixir
defp deps do
  [
    # Required: API + SDK
    {:otel_api, github: "yangbancode/otel", sparse: "apps/otel_api"},
    {:otel_sdk, github: "yangbancode/otel", sparse: "apps/otel_sdk"},

    # Optional: export to OTLP-compatible collectors via HTTP
    {:otel_exporter_otlp, github: "yangbancode/otel", sparse: "apps/otel_exporter_otlp"},

    # Optional: standardized attribute constants
    {:otel_semantic_conventions, github: "yangbancode/otel", sparse: "apps/otel_semantic_conventions"},

    # Optional: bridges Elixir Logger to OTel Logs pipeline
    {:otel_logger_handler, github: "yangbancode/otel", sparse: "apps/otel_logger_handler"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Setup

### Application Configuration

Add OTel setup to your application's `start/2` callback:

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # 1. Start OTel providers before your app's supervision tree
    setup_otel()

    children = [
      # ... your app's children ...
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp setup_otel do
    resource = Otel.SDK.Resource.create(%{
      "service.name" => "my_app",
      "service.version" => "1.0.0"
    })

    # --- Traces ---
    {:ok, _} =
      Otel.SDK.Trace.BatchProcessor.start_link(%{
        name: :otel_trace_bsp,
        resource: resource,
        exporter: {Otel.Exporter.OTLP.Traces, %{}}
      })

    {:ok, _} =
      Otel.SDK.Trace.TracerProvider.start_link(
        config: %{
          processors: [
            {Otel.SDK.Trace.BatchProcessor, %{reg_name: :otel_trace_bsp}}
          ]
        }
      )

    # --- Metrics ---
    {:ok, _} =
      Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

    # --- Logs ---
    {:ok, _} =
      Otel.SDK.Logs.BatchProcessor.start_link(%{
        name: :otel_log_blrp,
        exporter: {Otel.Exporter.OTLP.Logs, %{}}
      })

    {:ok, log_provider} =
      Otel.SDK.Logs.LoggerProvider.start_link(
        config: %{
          processors: [
            {Otel.SDK.Logs.BatchProcessor, %{reg_name: :otel_log_blrp}}
          ]
        }
      )

    # --- :logger bridge (optional) ---
    {_mod, bridge_config} =
      Otel.SDK.Logs.LoggerProvider.get_logger(log_provider, "my_app")

    :logger.add_handler(:otel, Otel.Logger.Handler, %{
      config: %{otel_logger: {Otel.SDK.Logs.Logger, bridge_config}}
    })

    :ok
  end
end
```

### Environment Variables

Configure the OTLP endpoint via environment variables — no code changes needed:

```bash
# Point to your Collector (default: http://localhost:4318)
export OTEL_EXPORTER_OTLP_ENDPOINT=http://collector.example.com:4318

# Optional: authentication headers
export OTEL_EXPORTER_OTLP_HEADERS=Authorization=Bearer my-token

# Optional: enable gzip compression
export OTEL_EXPORTER_OTLP_COMPRESSION=gzip
```

Signal-specific overrides are supported:

```bash
# Send traces to a different endpoint
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://tempo:4318/v1/traces

# Different timeout for metrics
export OTEL_EXPORTER_OTLP_METRICS_TIMEOUT=30000
```

## Usage

### Traces

```elixir
defmodule MyApp.OrderController do
  def create(params) do
    tracer = Otel.SDK.Trace.TracerProvider.get_tracer(:global, "my_app")

    Otel.API.Trace.with_span(tracer, "OrderController.create", fn _ctx ->
      span = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())
      Otel.API.Trace.Span.set_attribute(span, "http.method", "POST")

      # Nested span
      Otel.API.Trace.with_span(tracer, "validate_order", fn _ctx ->
        validate(params)
      end)

      # Another nested span
      Otel.API.Trace.with_span(tracer, "save_to_db", fn _ctx ->
        db_span = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())
        Otel.API.Trace.Span.set_attribute(db_span, "db.system", "postgresql")
        save(params)
      end)

      Otel.API.Trace.Span.set_attribute(span, "http.status_code", 201)
    end)
  end
end
```

### Metrics

```elixir
defmodule MyApp.Metrics do
  def setup(provider) do
    meter = Otel.SDK.Metrics.MeterProvider.get_meter(provider, "my_app")

    # Create instruments once
    Otel.API.Metrics.Meter.create_counter(meter, "http.requests", unit: "1")
    Otel.API.Metrics.Meter.create_histogram(meter, "http.duration", unit: "ms")
    Otel.API.Metrics.Meter.create_gauge(meter, "system.memory", unit: "bytes")

    meter
  end

  def record_request(meter, method, status, duration) do
    Otel.API.Metrics.Meter.record(meter, "http.requests", 1, %{
      method: method,
      status: status
    })

    Otel.API.Metrics.Meter.record(meter, "http.duration", duration, %{
      method: method
    })
  end
end
```

### Logs (Direct API)

```elixir
defmodule MyApp.PaymentService do
  def charge(order) do
    # logger is a {module, config} tuple from LoggerProvider.get_logger
    Otel.API.Logs.Logger.emit(logger(), %{
      severity_number: 9,
      severity_text: "INFO",
      body: "Processing payment for order #{order.id}",
      attributes: %{
        "order.id": order.id,
        "payment.amount": order.total
      }
    })

    # Logs emitted inside a span automatically include trace_id/span_id
  end
end
```

### Logs (:logger Bridge)

Once the `:logger` handler is registered in your application setup, all standard `Logger` calls are automatically exported:

```elixir
require Logger

# These are all automatically sent to your OTel Collector
Logger.info("User signed up", user_id: 123)
Logger.warning("Rate limit approaching", current: 95, limit: 100)
Logger.error("Payment failed", order_id: "ORD-456", reason: "declined")
```

The handler maps Elixir log levels to OTel severity numbers and extracts metadata (module, function, file, line) as attributes.


