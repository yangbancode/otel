# Tech Spec

## Project Overview

Pure Elixir implementation of the OpenTelemetry SDK. This project implements the OpenTelemetry specification using Erlang OTP / Elixir without depending on external OpenTelemetry libraries.

## Tech Stack

- **Language**: Elixir 1.19.5 / Erlang OTP 28
- **Version Management**: mise (pinned in `.mise.toml`)
- **Build Tool**: Mix
- **Target Spec**: [OpenTelemetry Specification v1.55.0](https://github.com/open-telemetry/opentelemetry-specification/releases/tag/v1.55.0)

## Project Scope

### Signals (in order of implementation)

1. **Traces** — Spans, Context Propagation, SpanProcessor, Sampler
2. **Metrics** — Meter, Instruments, MetricReader, Aggregation
3. **Logs** — LogRecord, LoggerProvider, LogRecordProcessor
4. **Baggage** — Context-based key-value propagation

All signals target stable items in the OpenTelemetry specification.

### Exporters (in order of implementation)

1. **Console (stdout)** — for development/debugging
2. **OTLP HTTP** — HTTP/protobuf
3. **OTLP gRPC** — gRPC/protobuf

### Implementation Phases

- **Phase 1**: Traces (Span, TracerProvider, Context Propagation, Console Exporter)
- **Phase 2**: OTLP HTTP Exporter + complete Traces
- **Phase 3**: Metrics
- **Phase 4**: Logs, Baggage, OTLP gRPC Exporter

### Out of Scope

- Dependencies on external OpenTelemetry libraries (e.g., opentelemetry-erlang)
- Experimental/Development status spec items

## Code Conventions

- Follow standard Elixir formatting (`mix format`)
- Use OTP patterns (GenServer, Supervisor, etc.) for concurrent components
- Write typespecs for public functions
- Keep modules focused and follow single-responsibility principle

## Development Setup

```bash
# Install Erlang/OTP and Elixir via mise
mise install

# Fetch dependencies
mix deps.get

# Run tests
mix test

# Format code
mix format

# Static analysis
mix credo
mix dialyzer
```
