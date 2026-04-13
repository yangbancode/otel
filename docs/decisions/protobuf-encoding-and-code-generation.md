# Protobuf Encoding & Code Generation

## Question

How to handle protobuf serialization/deserialization shared between HTTP and gRPC exporters? Which library, code generation vs runtime encoding?

## Decision

### Library: `protobuf` (protobuf-elixir)

hex.pm package: `protobuf` v0.16.0
GitHub: elixir-protobuf/protobuf

Chosen over `protox` because the Elixir gRPC library (`grpc` hex package) depends on `protobuf`. Using the same library for both HTTP and gRPC avoids dual-library conflicts.

### Code Generation Tool: `protoc` v34.1

Managed via `.mise.toml`. The `protoc-gen-elixir` plugin (installed via `mix escript.install hex protobuf 0.16.0`) generates Elixir modules from `.proto` files.

### Proto Source

`.proto` files from the `references/opentelemetry-proto` submodule (v1.10.0).

### Generated Modules

Location: `apps/otel_exporter_otlp/lib/otel/exporter/otlp/proto/`

| Proto | Generated Module Prefix |
|---|---|
| `common/v1/common.proto` | `Opentelemetry.Proto.Common.V1.*` |
| `resource/v1/resource.proto` | `Opentelemetry.Proto.Resource.V1.*` |
| `trace/v1/trace.proto` | `Opentelemetry.Proto.Trace.V1.*` |
| `collector/trace/v1/trace_service.proto` | `Opentelemetry.Proto.Collector.Trace.V1.*` |

### Generation Command

```bash
protoc \
  --proto_path=references/opentelemetry-proto \
  --elixir_out=apps/otel_exporter_otlp/lib/otel/exporter/otlp/proto \
  opentelemetry/proto/common/v1/common.proto \
  opentelemetry/proto/resource/v1/resource.proto \
  opentelemetry/proto/trace/v1/trace.proto \
  opentelemetry/proto/collector/trace/v1/trace_service.proto
```

### Design Notes

- Generated files are committed to the repository (not generated at build time)
- Regeneration needed only when proto definitions change (submodule update)
- erlang uses `gpb` (same approach — self-contained compiler, generated code committed)

## Compliance

- [OTLP Protocol](../compliance.md)
  * General — L87
  * Binary Protobuf Encoding — L400
  * JSON Protobuf Encoding — L409, L418, L426, L443
