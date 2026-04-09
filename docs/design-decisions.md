# Design Decisions (BEAM/OTP)

Decisions specific to implementing the OpenTelemetry SDK on the BEAM VM. These are not part of the OTel specification but are required to map spec concepts to Erlang/OTP primitives.

Each decision has its own document under [decisions/](decisions/) with related [compliance](compliance.md) items linked. When all linked compliance items are checked, the implementation for that decision is complete.

- Status: 🔲 not started / 🚧 in progress / ✅ done

## Phase 1: Traces

### Foundation

| # | Decision | Status |
|---|----------|--------|
| [DD-01](decisions/01-package-structure-and-module-namespacing.md) | Package Structure & Module Namespacing | 🔲 |
| [DD-02](decisions/02-behaviours-protocols-and-structs-convention.md) | Behaviours, Protocols, and Structs Convention | 🔲 |
| [DD-03](decisions/03-error-handling-strategy.md) | Error Handling Strategy | 🔲 |
| [DD-04](decisions/04-configuration-and-environment-variable-system.md) | Configuration & Environment Variable System | 🔲 |

### Common

| # | Decision | Status |
|---|----------|--------|
| [DD-05](decisions/05-anyvalue-type-system.md) | AnyValue Type System | 🔲 |
| [DD-06](decisions/06-attribute-and-attribute-collections.md) | Attribute & Attribute Collections | 🔲 |
| [DD-07](decisions/07-attribute-limits.md) | Attribute Limits | 🔲 |

### Context

| # | Decision | Status |
|---|----------|--------|
| [DD-08](decisions/08-context-data-structure-and-operations.md) | Context Data Structure & Operations | 🔲 |
| [DD-09](decisions/09-context-attach-detach-and-process-local-storage.md) | Context Attach/Detach & Process-Local Storage | 🔲 |
| [DD-10](decisions/10-cross-process-context-passing.md) | Cross-Process Context Passing | 🔲 |

### Resource

| # | Decision | Status |
|---|----------|--------|
| [DD-11](decisions/11-resource-creation-and-merge.md) | Resource Creation & Merge | 🔲 |
| [DD-12](decisions/12-resource-detection-and-environment-variables.md) | Resource Detection & Environment Variables | 🔲 |

### Trace API — Provider & Tracer

| # | Decision | Status |
|---|----------|--------|
| [DD-13](decisions/13-tracerprovider-api.md) | TracerProvider API | 🔲 |
| [DD-14](decisions/14-tracer-and-instrumentationscope.md) | Tracer & InstrumentationScope | 🔲 |

### Trace API — SpanContext

| # | Decision | Status |
|---|----------|--------|
| [DD-15](decisions/15-spancontext-struct.md) | SpanContext Struct | 🔲 |
| [DD-16](decisions/16-spancontext-validation-and-remote.md) | SpanContext Validation & Remote | 🔲 |
| [DD-17](decisions/17-tracestate.md) | TraceState | 🔲 |

### Trace API — Span

| # | Decision | Status |
|---|----------|--------|
| [DD-18](decisions/18-span-interface-and-lifecycle.md) | Span Interface & Lifecycle | 🔲 |
| [DD-19](decisions/19-span-creation.md) | Span Creation | 🔲 |
| [DD-20](decisions/20-span-operations-attributes-and-events.md) | Span Operations: Attributes & Events | 🔲 |
| [DD-21](decisions/21-span-operations-links-status-end.md) | Span Operations: Links, Status, End | 🔲 |
| [DD-22](decisions/22-span-operations-record-exception.md) | Span Operations: RecordException | 🔲 |
| [DD-23](decisions/23-nonrecordingspan-and-no-sdk-behavior.md) | NonRecordingSpan & No-SDK Behavior | 🔲 |
| [DD-24](decisions/24-trace-context-interaction.md) | Trace Context Interaction | 🔲 |

### Trace SDK — Provider & Configuration

| # | Decision | Status |
|---|----------|--------|
| [DD-25](decisions/25-tracerprovider-sdk-configuration.md) | TracerProvider SDK: Configuration | 🔲 |
| [DD-26](decisions/26-tracerprovider-sdk-shutdown-and-forceflush.md) | TracerProvider SDK: Shutdown & ForceFlush | 🔲 |

### Trace SDK — Sampling

| # | Decision | Status |
|---|----------|--------|
| [DD-27](decisions/27-sampler-interface-and-shouldsample.md) | Sampler Interface & ShouldSample | 🔲 |
| [DD-28](decisions/28-built-in-samplers.md) | Built-in Samplers | 🔲 |

### Trace SDK — Span Creation & Storage

| # | Decision | Status |
|---|----------|--------|
| [DD-29](decisions/29-id-generation.md) | ID Generation | 🔲 |
| [DD-30](decisions/30-sdk-span-creation-flow.md) | SDK Span Creation Flow | 🔲 |
| [DD-31](decisions/31-span-storage-and-ets-design.md) | Span Storage & ETS Design | 🔲 |

### Trace SDK — Span Processors

| # | Decision | Status |
|---|----------|--------|
| [DD-32](decisions/32-spanprocessor-interface.md) | SpanProcessor Interface | 🔲 |
| [DD-33](decisions/33-simplespanprocessor.md) | SimpleSpanProcessor | 🔲 |
| [DD-34](decisions/34-batchspanprocessor.md) | BatchSpanProcessor | 🔲 |

### Trace SDK — Span Exporters

| # | Decision | Status |
|---|----------|--------|
| [DD-35](decisions/35-spanexporter-interface.md) | SpanExporter Interface | 🔲 |
| [DD-36](decisions/36-console-stdout-exporter.md) | Console (stdout) Exporter | 🔲 |

### Propagators

| # | Decision | Status |
|---|----------|--------|
| [DD-37](decisions/37-textmappropagator-interface.md) | TextMapPropagator Interface | 🔲 |
| [DD-38](decisions/38-composite-propagator-and-global-registration.md) | Composite Propagator & Global Registration | 🔲 |
| [DD-39](decisions/39-w3c-tracecontext-propagator.md) | W3C TraceContext Propagator | 🔲 |

### Baggage

| # | Decision | Status |
|---|----------|--------|
| [DD-40](decisions/40-baggage-api.md) | Baggage API | 🔲 |
| [DD-41](decisions/41-w3c-baggage-propagator.md) | W3C Baggage Propagator | 🔲 |

### OTP Infrastructure

| # | Decision | Status |
|---|----------|--------|
| [DD-42](decisions/42-supervision-tree-structure.md) | Supervision Tree Structure | 🔲 |
| [DD-43](decisions/43-application-boot-order.md) | Application Boot Order | 🔲 |

## Phase 2: OTLP HTTP Exporter

| # | Decision | Status |
|---|----------|--------|
| [DD-44](decisions/44-otlp-http-exporter.md) | OTLP HTTP Exporter | 🔲 |
| [DD-50](decisions/50-exporter-packaging-strategy.md) | Exporter Packaging Strategy | 🔲 |

## Phase 3: Metrics

| # | Decision | Status |
|---|----------|--------|
| [DD-45](decisions/45-metrics-api.md) | Metrics API | 🔲 |
| [DD-46](decisions/46-metrics-sdk.md) | Metrics SDK | 🔲 |

## Phase 4: Logs, Baggage, OTLP gRPC

| # | Decision | Status |
|---|----------|--------|
| [DD-47](decisions/47-logs-api-and-sdk.md) | Logs API & SDK | 🔲 |
| [DD-48](decisions/48-logger-integration.md) | :logger Integration | 🔲 |
| [DD-49](decisions/49-otlp-grpc-exporter.md) | OTLP gRPC Exporter | 🔲 |
