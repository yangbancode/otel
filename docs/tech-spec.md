# Tech Spec

## Project Overview

Pure Elixir implementation of the OpenTelemetry SDK. This project implements the OpenTelemetry specification using Erlang OTP / Elixir without depending on external OpenTelemetry libraries.

## Tech Stack

- **Language**: Erlang/OTP 26.2.5.19, Elixir 1.18.4-otp-26
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

## Type System

Every OpenTelemetry spec entity — primitive value containers (`AnyValue`, `Attribute`), opaque identifiers (`TraceId`, `SpanId`), and composite records (`Link`, `Event`, `Status`, `LogRecord`, `Measurement`, `Instrument`) — is represented as a dedicated Elixir struct with 1:1 correspondence to its spec definition. Native-type shortcuts (plain maps, tuples, raw binaries) are not used for spec-defined entities.

See [Spec-First Type System](decisions/spec-first-type-system.md) for rationale, scope, and implementation phases.

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
