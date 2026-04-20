# Tech Spec

## Project Overview

Pure Elixir implementation of the OpenTelemetry SDK. This project implements the OpenTelemetry specification using Erlang OTP / Elixir without depending on external OpenTelemetry libraries.

## Tech Stack

- **Language**: Erlang/OTP 26.2.5.19, Elixir 1.18.4-otp-26
- **Version Management**: mise (pinned in `.mise.toml`)
- **Build Tool**: Mix
- **Target Specs**:
  - [OpenTelemetry Specification v1.55.0](https://github.com/open-telemetry/opentelemetry-specification/releases/tag/v1.55.0)
  - [W3C Trace Context Level 2](https://www.w3.org/TR/trace-context-2/) — mandated by OTel for `traceparent`/`tracestate` wire format (`context/api-propagators.md` L383 MUST)
  - [W3C Baggage](https://www.w3.org/TR/baggage/) — `baggage` header wire format
  - [OpenTelemetry Protocol (OTLP)](https://github.com/open-telemetry/opentelemetry-proto) — exporter wire format
  - [OpenTelemetry Semantic Conventions](https://github.com/open-telemetry/semantic-conventions) — attribute key constants

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
