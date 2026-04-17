# Spec-First Type System

## Question

How should OpenTelemetry spec entities be represented in Elixir? Native types (maps, tuples, raw binaries, integer ranges) with conversion at export boundaries, or a dedicated struct per spec entity — including primitive value containers and opaque identifiers?

## Decision

### Principle

Every OpenTelemetry entity — primitive, composite, or identifier — is represented as a dedicated Elixir struct with 1:1 correspondence to its spec definition. No native-type shortcuts for spec-defined entities.

The project is a direct language port of the specification; introducing native-type exceptions at the surface would bias the SDK toward an Elixir-idiom variant rather than a faithful implementation. Type representation is a foundational direction, not an optimization.

### Scope

All of the following are modeled as structs:

**Primitive / cross-signal (new namespace `Otel.API.Common`):**

| Entity | Module | Purpose |
|---|---|---|
| `AnyValue` | `Otel.API.Common.AnyValue` | Tagged union: string / bool / int / double / bytes / array / kvlist |
| `Attribute` | `Otel.API.Common.Attribute` | Key + AnyValue-wrapped value |

**Trace identifiers and composites:**

| Entity | Module | Replaces |
|---|---|---|
| `TraceId` | `Otel.API.Trace.TraceId` | `non_neg_integer()` (128-bit) |
| `SpanId` | `Otel.API.Trace.SpanId` | `non_neg_integer()` (64-bit) |
| `Link` | `Otel.API.Trace.Link` | `{SpanContext, attributes}` tuple |
| `Event` | `Otel.API.Trace.Event` | `name + opts` args |
| `Status` | `Otel.API.Trace.Status` | `code + description` separate args |

**Logs composites:**

| Entity | Module | Replaces |
|---|---|---|
| `LogRecord` | `Otel.API.Logs.LogRecord` | Anonymous map type |
| `SeverityNumber` | `Otel.API.Logs.SeverityNumber` | `1..24` integer range |

**Metrics composites:**

| Entity | Module | Replaces |
|---|---|---|
| `Measurement` | `Otel.API.Metrics.Measurement` | `{value, attributes}` tuple |
| `Instrument` | `Otel.API.Metrics.Instrument` | Name-keyed implicit reference |

### Rationale

- **Spec fidelity.** Users encounter the same entity names the specification defines. No translation step between reading the spec and reading the module list.
- **Dialyzer discrimination.** `TraceId.t()` and `SpanId.t()` are distinct types; confusion that a raw `non_neg_integer()` would permit is caught at analysis time.
- **Centralized validation.** Constructor functions (`new/*`) are the single point of format enforcement — length, charset, byte size — rather than scattered checks at each call site.
- **Export boundary simplification.** OTLP encoders operate on structured data with known field shapes. Type inference at the encoder (e.g., deciding whether a value maps to `string_value` or `int_value` at encode time) is removed.
- **Pre-publish commitment.** `otel_api` has not yet been published to hex.pm. The native-types alternative would force a breaking-change migration after the first release.

### Trade-offs Accepted

- **Caller boilerplate** at construction sites. `Attribute.new("http.method", "GET")` replaces `{"http.method", "GET"}`. Heavy attribute users see the largest ergonomic cost.
- **Per-value allocation.** Each value passes through a struct rather than a primitive. Known runtime cost, accepted for consistency.
- **Divergence from opentelemetry-erlang, opentelemetry-java, opentelemetry-go.** Those implementations use native types for primitives. This project deliberately takes a different position on type-system strictness.
- **User feedback is deferred to post-publish.** Any ergonomic helpers (e.g., sugar constructors, macro-based builders) are reserved as additive iterations after `0.1.0` ships and real usage patterns surface.

### Naming Convention

- Cross-signal primitive types live under `Otel.API.Common.*`.
- Signal-specific types stay in their signal namespace (`Otel.API.Trace.*`, `Otel.API.Logs.*`, `Otel.API.Metrics.*`).
- Every struct provides `new/*` constructors that validate inputs and return the opaque `t()` type.
- No bang (`!`) variants at the API layer — invalid inputs raise from the constructor with a deterministic exception (the usual Elixir idiom for mis-used public APIs).

### Implementation Phases

This decision is landed across four follow-up PRs, in this order, because later phases depend on the primitive types from the first phase:

1. **Primitives** — `AnyValue`, `Attribute`, `TraceId`, `SpanId`
2. **Trace composites** — `Link`, `Event`, `Status`
3. **Logs composites** — `LogRecord`, `SeverityNumber`
4. **Metrics composites** — `Measurement`, `Instrument`

Each phase updates `otel_api`, `otel_sdk`, and `otel_exporter_otlp` in one PR so no intermediate state ships with mixed representations. The final phase precedes hex.pm publishing of `otel_api`.

### Supersedes

The working assumption — recorded only in internal project notes — that primitive values (`AnyValue`, `Attribute`) and opaque identifiers (`TraceId`, `SpanId`) would be kept as native Elixir types following the opentelemetry-erlang pattern. No prior Decision document formalized that approach; this document is the first authoritative statement on type representation across the project.

Existing Decision documents written before this policy describe native-type code examples for the eleven promoted entities. Those examples are factually inconsistent with the policy and will be revised alongside the implementation in each phase PR.

## Compliance

No spec compliance items — this is an engineering decision that shapes how every spec entity is represented. Individual entities' compliance items remain tracked under their respective signal sections in [compliance.md](../compliance.md).
