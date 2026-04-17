# Package Structure & Module Namespacing

## Question

How to organize the Elixir package into modules that map to OTel's API/SDK separation? Should API and SDK be separate OTP applications or a single Mix project?

## Decision

### Umbrella Project

Use an umbrella project. The top-level `otel` repository is the umbrella, and each logical component is a separate OTP application under `apps/`.

Reasons for umbrella over single Mix project:

- OTel spec explicitly separates API and SDK. Library authors should depend on API only, without pulling in SDK implementation.
- Exporters carry their own external dependencies (protobuf, HTTP/gRPC clients). Separating them prevents unnecessary dependency leakage.
- Each app can be versioned and published to hex.pm independently.

### Applications

```
otel/
├── apps/
│   ├── otel_api/                    # Otel.API
│   ├── otel_sdk/                    # Otel.SDK (includes Console Exporter)
│   ├── otel_semantic_conventions/   # Otel.SemConv
│   ├── otel_exporter_otlp/         # Otel.Exporter.OTLP
│   └── otel_logger_handler/        # Otel.Logger.Handler
```

#### `otel_api` — Otel.API

API behaviours and data structures. Zero external dependencies. Library authors depend on this only.

Contains:

- Trace API (TracerProvider, Tracer, Span behaviours)
- Context operations
- Propagator behaviours
- Baggage API

Without SDK, all operations are no-op (spec requirement).

#### `otel_sdk` — Otel.SDK

SDK implementation. Depends on `otel_api`.

Contains:

- TracerProvider SDK implementation
- Resource
- Sampler, SpanProcessor, SpanExporter behaviours and built-in implementations
- Logs SDK (Phase 4)
- Metrics SDK (Phase 3)

#### `otel_semantic_conventions` — Otel.SemConv

Attribute key constants and metric names auto-generated from the OpenTelemetry Semantic Conventions repository via OTel Weaver. Zero dependencies. Follows the `SemConv` abbreviation convention used by the Erlang ecosystem.

Attributes and metrics live under separate sub-namespaces, stable items only (incubating/development is out of scope per tech-spec):

```elixir
Otel.SemConv.Attributes.HTTP   # http.* attribute keys
Otel.SemConv.Metrics.HTTP      # http.* metric names
```

#### Console Exporter (in `otel_sdk`)

Console exporter for debugging/development lives inside `otel_sdk` as `Otel.SDK.Trace.Exporter.Console`. Built-in to SDK — no separate app needed for development use.

#### `otel_exporter_otlp` — Otel.Exporter.OTLP

OTLP protocol exporter supporting both HTTP and gRPC transports, switched via configuration. Contains shared OTLP logic (protobuf encoding, retry/backoff).

```elixir
# HTTP (default)
config :otel_exporter_otlp, protocol: :http_protobuf

# gRPC
config :otel_exporter_otlp, protocol: :grpc
```

HTTP and gRPC are combined in a single app following `opentelemetry-erlang` convention. Both transports share the same protobuf encoding and retry logic — only the transport layer differs.

#### `otel_logger_handler` — Otel.Logger.Handler

Bridge from Erlang `:logger` to OTel Logs API. Registers a `:logger` handler that converts log messages into OTel Log Records without requiring any changes to existing application logging code.

Depends on `otel_api` (Logs API).

### Dependency Graph

```
otel_exporter_otlp ────→ otel_sdk ──→ otel_api
otel_logger_handler ─────────────────→ otel_api
otel_semantic_conventions              (standalone)
```

Dependencies are strictly unidirectional. No circular dependencies.

### Implementation Phases

| App | Phase |
|-----|-------|
| `otel_api` | Phase 1: Traces |
| `otel_sdk` | Phase 1: Traces (includes Console Exporter) |
| `otel_semantic_conventions` | Phase 1: Traces |
| `otel_exporter_otlp` | Phase 2: OTLP HTTP, Phase 4: gRPC |
| `otel_logger_handler` | Phase 4: Logs |

### Module Naming Convention

**App namespace mapping:**

| App name (snake_case) | Module namespace |
|-----------------------|-----------------|
| `otel_api` | `Otel.API` |
| `otel_sdk` | `Otel.SDK` |
| `otel_semantic_conventions` | `Otel.SemConv` |
| `otel_exporter_otlp` | `Otel.Exporter.OTLP` |
| `otel_logger_handler` | `Otel.Logger.Handler` |

Acronyms (`API`, `SDK`, `OTLP`, `HTTP`, `GRPC`) use full uppercase. This is consistent with Elixir standard library conventions (`URI`, `IO`, `JSON`) and does not violate Credo's `ModuleNames` check.

**File path convention:**

Module namespaces map to lowercase file paths:

```
apps/otel_api/lib/otel/api.ex            → defmodule Otel.API
apps/otel_sdk/lib/otel/sdk.ex            → defmodule Otel.SDK
apps/otel_exporter_otlp/lib/otel/exporter/otlp.ex → defmodule Otel.Exporter.OTLP
```

**Sub-module pattern:** `<App Namespace>.<Signal>.<Component>`

```elixir
# Examples (concrete module names decided in individual decisions)
Otel.API.Trace.Tracer
Otel.SDK.Trace.SpanProcessor
Otel.SDK.Trace.Exporter.Console
Otel.Exporter.OTLP.Trace
```

### Versioning Strategy

Each app is versioned independently, starting at `0.1.0`. Inter-app compatibility is declared via semver constraints in `mix.exs`:

```elixir
# otel_sdk/mix.exs
defp deps do
  [{:otel_api, "~> 0.1", in_umbrella: true}]
end
```

Release notes are managed through GitHub Releases per app. The target OTel spec version is recorded in [tech-spec.md](../tech-spec.md), not in individual `mix.exs` files.

### Scope Boundary

Included in this umbrella (OTel spec components):

- API, SDK, Exporters, Semantic Conventions, Logger Handler

Excluded (separate repositories):

- Framework instrumentation libraries (`otel_phoenix`, `otel_ecto`, etc.)
- These are not part of the OTel specification

## Compliance
