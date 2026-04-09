# Tech Spec

## Project Overview

Pure Elixir implementation of the OpenTelemetry SDK. This project implements the OpenTelemetry specification using Erlang OTP / Elixir without depending on external OpenTelemetry libraries.

## Tech Stack

- **Language**: Erlang/OTP 28.4.2, Elixir 1.19.5-otp-28
- **Version Management**: mise (pinned in `.mise.toml`)
- **Build Tool**: Mix
- **Target Spec**: [OpenTelemetry Specification v1.55.0](https://github.com/open-telemetry/opentelemetry-specification/releases/tag/v1.55.0)

## Project Scope

### Signals

- **Traces** — Spans, Context Propagation, SpanProcessor, Sampler
- **Metrics** — Meter, Instruments, MetricReader, Aggregation
- **Logs** — LogRecord, LoggerProvider, LogRecordProcessor
- **Baggage** — Context-based key-value propagation

All signals target stable items in the OpenTelemetry specification.

### Exporters

- **Console (stdout)** — for development/debugging
- **OTLP HTTP** — HTTP/protobuf
- **OTLP gRPC** — gRPC/protobuf

### Semantic Conventions

- Auto-generated attribute key constants from the [OpenTelemetry Semantic Conventions](https://github.com/open-telemetry/semantic-conventions) repository

Implementation order and phases are defined in [Decisions](decisions.md).

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
