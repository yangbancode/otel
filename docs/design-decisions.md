# Design Decisions (BEAM/OTP)

Decisions specific to implementing the OpenTelemetry SDK on the BEAM VM. These are not part of the OTel specification but are required to map spec concepts to Erlang/OTP primitives.

Each decision has its own document under [decisions/](decisions/) with related [compliance](compliance.md) items linked. When all linked compliance items are checked, the implementation for that decision is complete.

## Phase 1: Traces

### Foundation
- [ ] [01 — Package Structure & Module Namespacing](decisions/01-package-structure-and-module-namespacing.md)
- [ ] [02 — Behaviours, Protocols, and Structs Convention](decisions/02-behaviours-protocols-and-structs-convention.md)
- [ ] [03 — Error Handling Strategy](decisions/03-error-handling-strategy.md)
- [ ] [04 — Configuration & Environment Variable System](decisions/04-configuration-and-environment-variable-system.md)

### Common
- [ ] [05 — AnyValue Type System](decisions/05-anyvalue-type-system.md)
- [ ] [06 — Attribute & Attribute Collections](decisions/06-attribute-and-attribute-collections.md)
- [ ] [07 — Attribute Limits](decisions/07-attribute-limits.md)

### Context
- [ ] [08 — Context Data Structure & Operations](decisions/08-context-data-structure-and-operations.md)
- [ ] [09 — Context Attach/Detach & Process-Local Storage](decisions/09-context-attach-detach-and-process-local-storage.md)
- [ ] [10 — Cross-Process Context Passing](decisions/10-cross-process-context-passing.md)

### Resource
- [ ] [11 — Resource Creation & Merge](decisions/11-resource-creation-and-merge.md)
- [ ] [12 — Resource Detection & Environment Variables](decisions/12-resource-detection-and-environment-variables.md)

### Trace API — Provider & Tracer
- [ ] [13 — TracerProvider API](decisions/13-tracerprovider-api.md)
- [ ] [14 — Tracer & InstrumentationScope](decisions/14-tracer-and-instrumentationscope.md)

### Trace API — SpanContext
- [ ] [15 — SpanContext Struct](decisions/15-spancontext-struct.md)
- [ ] [16 — SpanContext Validation & Remote](decisions/16-spancontext-validation-and-remote.md)
- [ ] [17 — TraceState](decisions/17-tracestate.md)

### Trace API — Span
- [ ] [18 — Span Interface & Lifecycle](decisions/18-span-interface-and-lifecycle.md)
- [ ] [19 — Span Creation](decisions/19-span-creation.md)
- [ ] [20 — Span Operations: Attributes & Events](decisions/20-span-operations-attributes-and-events.md)
- [ ] [21 — Span Operations: Links, Status, End](decisions/21-span-operations-links-status-end.md)
- [ ] [22 — Span Operations: RecordException](decisions/22-span-operations-record-exception.md)
- [ ] [23 — NonRecordingSpan & No-SDK Behavior](decisions/23-nonrecordingspan-and-no-sdk-behavior.md)
- [ ] [24 — Trace Context Interaction](decisions/24-trace-context-interaction.md)

### Trace SDK — Provider & Configuration
- [ ] [25 — TracerProvider SDK: Configuration](decisions/25-tracerprovider-sdk-configuration.md)
- [ ] [26 — TracerProvider SDK: Shutdown & ForceFlush](decisions/26-tracerprovider-sdk-shutdown-and-forceflush.md)

### Trace SDK — Sampling
- [ ] [27 — Sampler Interface & ShouldSample](decisions/27-sampler-interface-and-shouldsample.md)
- [ ] [28 — Built-in Samplers](decisions/28-built-in-samplers.md)

### Trace SDK — Span Creation & Storage
- [ ] [29 — ID Generation](decisions/29-id-generation.md)
- [ ] [30 — SDK Span Creation Flow](decisions/30-sdk-span-creation-flow.md)
- [ ] [31 — Span Storage & ETS Design](decisions/31-span-storage-and-ets-design.md)

### Trace SDK — Span Processors
- [ ] [32 — SpanProcessor Interface](decisions/32-spanprocessor-interface.md)
- [ ] [33 — SimpleSpanProcessor](decisions/33-simplespanprocessor.md)
- [ ] [34 — BatchSpanProcessor](decisions/34-batchspanprocessor.md)

### Trace SDK — Span Exporters
- [ ] [35 — SpanExporter Interface](decisions/35-spanexporter-interface.md)
- [ ] [36 — Console (stdout) Exporter](decisions/36-console-stdout-exporter.md)

### Propagators
- [ ] [37 — TextMapPropagator Interface](decisions/37-textmappropagator-interface.md)
- [ ] [38 — Composite Propagator & Global Registration](decisions/38-composite-propagator-and-global-registration.md)
- [ ] [39 — W3C TraceContext Propagator](decisions/39-w3c-tracecontext-propagator.md)

### Baggage
- [ ] [40 — Baggage API](decisions/40-baggage-api.md)
- [ ] [41 — W3C Baggage Propagator](decisions/41-w3c-baggage-propagator.md)

### OTP Infrastructure
- [ ] [42 — Supervision Tree Structure](decisions/42-supervision-tree-structure.md)
- [ ] [43 — Application Boot Order](decisions/43-application-boot-order.md)

## Phase 2: OTLP HTTP Exporter
- [ ] [44 — OTLP HTTP Exporter](decisions/44-otlp-http-exporter.md)
- [ ] [50 — Exporter Packaging Strategy](decisions/50-exporter-packaging-strategy.md)

## Phase 3: Metrics
- [ ] [45 — Metrics API](decisions/45-metrics-api.md)
- [ ] [46 — Metrics SDK](decisions/46-metrics-sdk.md)

## Phase 4: Logs, Baggage, OTLP gRPC
- [ ] [47 — Logs API & SDK](decisions/47-logs-api-and-sdk.md)
- [ ] [48 — :logger Integration](decisions/48-logger-integration.md)
- [ ] [49 — OTLP gRPC Exporter](decisions/49-otlp-grpc-exporter.md)
