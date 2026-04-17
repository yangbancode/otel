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
  - [x] Auto-generated constants (stable only)
- **Integrations**
  - [x] Erlang `:logger` bridge

## Requirements

- Elixir 1.18+
- Erlang/OTP 26+

## Packages

| App | Description |
|---|---|
| [`otel_api`](apps/otel_api) | Instrumentation API — Tracer, Meter, Logger, Span, Baggage |
| [`otel_sdk`](apps/otel_sdk) | SDK implementation — providers, processors, samplers, resource detection |
| [`otel_semantic_conventions`](apps/otel_semantic_conventions) | Auto-generated attribute and metric key constants |
| [`otel_exporter_otlp`](apps/otel_exporter_otlp) | OTLP HTTP exporter (protobuf over HTTP/1.1) |
| [`otel_logger_handler`](apps/otel_logger_handler) | Elixir `:logger` bridge to OTel Logs |

Each app is published independently on hex.pm. Refer to the per-app README for installation and usage.

## Architecture

```
your code → otel_api → otel_sdk → otel_exporter_otlp → OTel Collector
```

- **`otel_api`** — instrumentation surface your code calls (`Tracer.start_span`, `Meter.record`, `Logger.emit`, etc.)
- **`otel_sdk`** — the behaviours behind the API: providers, processors (Simple/Batch), samplers, span storage, resource detection
- **`otel_exporter_otlp`** — serializes to protobuf and ships to a collector/backend over HTTP/1.1

Optional:

- **`otel_semantic_conventions`** — attribute-key constants (`http.request.method`, `db.system.name`, ...) to keep emitted attributes consistent with the OTel spec
- **`otel_logger_handler`** — registers as a `:logger` handler so standard `Logger.info/warning/error` calls flow into the OTel Logs pipeline

## License

Released into the public domain under the [Unlicense](LICENSE).
