# Design Decisions (BEAM/OTP)

Decisions specific to implementing the OpenTelemetry SDK on the BEAM VM. These are not part of the OTel specification but are required to map spec concepts to Erlang/OTP primitives.

Each decision has its own document under [decisions/](decisions/) with related [compliance](compliance.md) items linked. When all linked compliance items are checked, the implementation for that decision is complete.

- Status: 🔲 not started / 🚧 in progress / ✅ done

## Phase 1: Traces

### Foundation

| # | Decision | Status |
|---|----------|--------|
| [01](decisions/01-package-structure-and-module-namespacing.md) | Package Structure & Module Namespacing | 🔲 |
| [02](decisions/02-behaviours-protocols-and-structs-convention.md) | Behaviours, Protocols, and Structs Convention | 🔲 |
| [03](decisions/03-error-handling-strategy.md) | Error Handling Strategy | 🔲 |
| [04](decisions/04-configuration-and-environment-variable-system.md) | Configuration & Environment Variable System | 🔲 |

### Common

| # | Decision | Status |
|---|----------|--------|
| [05](decisions/05-anyvalue-type-system.md) | AnyValue Type System | 🔲 |
| [06](decisions/06-attribute-and-attribute-collections.md) | Attribute & Attribute Collections | 🔲 |
| [07](decisions/07-attribute-limits.md) | Attribute Limits | 🔲 |

### Context

| # | Decision | Status |
|---|----------|--------|
| [08](decisions/08-context-data-structure-and-operations.md) | Context Data Structure & Operations | 🔲 |
| [09](decisions/09-context-attach-detach-and-process-local-storage.md) | Context Attach/Detach & Process-Local Storage | 🔲 |
| [10](decisions/10-cross-process-context-passing.md) | Cross-Process Context Passing | 🔲 |

### Resource

| # | Decision | Status |
|---|----------|--------|
| [11](decisions/11-resource-creation-and-merge.md) | Resource Creation & Merge | 🔲 |
| [12](decisions/12-resource-detection-and-environment-variables.md) | Resource Detection & Environment Variables | 🔲 |

### Trace API — Provider & Tracer

| # | Decision | Status |
|---|----------|--------|
| [13](decisions/13-tracerprovider-api.md) | TracerProvider API | 🔲 |
| [14](decisions/14-tracer-and-instrumentationscope.md) | Tracer & InstrumentationScope | 🔲 |

### Trace API — SpanContext

| # | Decision | Status |
|---|----------|--------|
| [15](decisions/15-spancontext-struct.md) | SpanContext Struct | 🔲 |
| [16](decisions/16-spancontext-validation-and-remote.md) | SpanContext Validation & Remote | 🔲 |
| [17](decisions/17-tracestate.md) | TraceState | 🔲 |

### Trace API — Span

| # | Decision | Status |
|---|----------|--------|
| [18](decisions/18-span-interface-and-lifecycle.md) | Span Interface & Lifecycle | 🔲 |
| [19](decisions/19-span-creation.md) | Span Creation | 🔲 |
| [20](decisions/20-span-operations-attributes-and-events.md) | Span Operations: Attributes & Events | 🔲 |
| [21](decisions/21-span-operations-links-status-end.md) | Span Operations: Links, Status, End | 🔲 |
| [22](decisions/22-span-operations-record-exception.md) | Span Operations: RecordException | 🔲 |
| [23](decisions/23-nonrecordingspan-and-no-sdk-behavior.md) | NonRecordingSpan & No-SDK Behavior | 🔲 |
| [24](decisions/24-trace-context-interaction.md) | Trace Context Interaction | 🔲 |

### Trace SDK — Provider & Configuration

| # | Decision | Status |
|---|----------|--------|
| [25](decisions/25-tracerprovider-sdk-configuration.md) | TracerProvider SDK: Configuration | 🔲 |
| [26](decisions/26-tracerprovider-sdk-shutdown-and-forceflush.md) | TracerProvider SDK: Shutdown & ForceFlush | 🔲 |

### Trace SDK — Sampling

| # | Decision | Status |
|---|----------|--------|
| [27](decisions/27-sampler-interface-and-shouldsample.md) | Sampler Interface & ShouldSample | 🔲 |
| [28](decisions/28-built-in-samplers.md) | Built-in Samplers | 🔲 |

### Trace SDK — Span Creation & Storage

| # | Decision | Status |
|---|----------|--------|
| [29](decisions/29-id-generation.md) | ID Generation | 🔲 |
| [30](decisions/30-sdk-span-creation-flow.md) | SDK Span Creation Flow | 🔲 |
| [31](decisions/31-span-storage-and-ets-design.md) | Span Storage & ETS Design | 🔲 |

### Trace SDK — Span Processors

| # | Decision | Status |
|---|----------|--------|
| [32](decisions/32-spanprocessor-interface.md) | SpanProcessor Interface | 🔲 |
| [33](decisions/33-simplespanprocessor.md) | SimpleSpanProcessor | 🔲 |
| [34](decisions/34-batchspanprocessor.md) | BatchSpanProcessor | 🔲 |

### Trace SDK — Span Exporters

| # | Decision | Status |
|---|----------|--------|
| [35](decisions/35-spanexporter-interface.md) | SpanExporter Interface | 🔲 |
| [36](decisions/36-console-stdout-exporter.md) | Console (stdout) Exporter | 🔲 |

### Propagators

| # | Decision | Status |
|---|----------|--------|
| [37](decisions/37-textmappropagator-interface.md) | TextMapPropagator Interface | 🔲 |
| [38](decisions/38-composite-propagator-and-global-registration.md) | Composite Propagator & Global Registration | 🔲 |
| [39](decisions/39-w3c-tracecontext-propagator.md) | W3C TraceContext Propagator | 🔲 |

### Baggage

| # | Decision | Status |
|---|----------|--------|
| [40](decisions/40-baggage-api.md) | Baggage API | 🔲 |
| [41](decisions/41-w3c-baggage-propagator.md) | W3C Baggage Propagator | 🔲 |

### OTP Infrastructure

| # | Decision | Status |
|---|----------|--------|
| [42](decisions/42-supervision-tree-structure.md) | Supervision Tree Structure | 🔲 |
| [43](decisions/43-application-boot-order.md) | Application Boot Order | 🔲 |

## Phase 2: OTLP HTTP Exporter

| # | Decision | Status |
|---|----------|--------|
| [44](decisions/44-otlp-http-exporter.md) | OTLP HTTP Exporter | 🔲 |
| [50](decisions/50-exporter-packaging-strategy.md) | Exporter Packaging Strategy | 🔲 |

## Phase 3: Metrics

| # | Decision | Status |
|---|----------|--------|
| [45](decisions/45-metrics-api.md) | Metrics API | 🔲 |
| [46](decisions/46-metrics-sdk.md) | Metrics SDK | 🔲 |

## Phase 4: Logs, Baggage, OTLP gRPC

| # | Decision | Status |
|---|----------|--------|
| [47](decisions/47-logs-api-and-sdk.md) | Logs API & SDK | 🔲 |
| [48](decisions/48-logger-integration.md) | :logger Integration | 🔲 |
| [49](decisions/49-otlp-grpc-exporter.md) | OTLP gRPC Exporter | 🔲 |
