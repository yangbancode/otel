# Design Decisions (BEAM/OTP)

Decisions specific to implementing the OpenTelemetry SDK on the BEAM VM. These are not part of the OTel specification but are required to map spec concepts to Erlang/OTP primitives.

Each decision has its own document under [decisions/](decisions/) with related [compliance](compliance.md) items linked. When all linked compliance items are checked, the implementation for that decision is complete.

## Phase 1: Traces

### Foundation
- [ ] [Package Structure & Module Namespacing](decisions/package-structure-and-module-namespacing.md)
- [ ] [Behaviours, Protocols, and Structs Convention](decisions/behaviours-protocols-and-structs-convention.md)
- [ ] [Error Handling Strategy](decisions/error-handling-strategy.md)
- [ ] [Configuration & Environment Variable System](decisions/configuration-and-environment-variable-system.md)

### Common
- [ ] [AnyValue Type System](decisions/anyvalue-type-system.md)
- [ ] [Attribute & Attribute Collections](decisions/attribute-and-attribute-collections.md)
- [ ] [Attribute Limits](decisions/attribute-limits.md)

### Context
- [ ] [Context Data Structure & Operations](decisions/context-data-structure-and-operations.md)
- [ ] [Context Attach/Detach & Process-Local Storage](decisions/context-attach-detach-and-process-local-storage.md)
- [ ] [Cross-Process Context Passing](decisions/cross-process-context-passing.md)

### Resource
- [ ] [Resource Creation & Merge](decisions/resource-creation-and-merge.md)
- [ ] [Resource Detection & Environment Variables](decisions/resource-detection-and-environment-variables.md)

### Trace API — Provider & Tracer
- [ ] [TracerProvider API](decisions/tracerprovider-api.md)
- [ ] [Tracer & InstrumentationScope](decisions/tracer-and-instrumentationscope.md)

### Trace API — SpanContext
- [ ] [SpanContext Struct](decisions/spancontext-struct.md)
- [ ] [SpanContext Validation & Remote](decisions/spancontext-validation-and-remote.md)
- [ ] [TraceState](decisions/tracestate.md)

### Trace API — Span
- [ ] [Span Interface & Lifecycle](decisions/span-interface-and-lifecycle.md)
- [ ] [Span Creation](decisions/span-creation.md)
- [ ] [Span Operations: Attributes & Events](decisions/span-operations-attributes-and-events.md)
- [ ] [Span Operations: Links, Status, End](decisions/span-operations-links-status-end.md)
- [ ] [Span Operations: RecordException](decisions/span-operations-record-exception.md)
- [ ] [NonRecordingSpan & No-SDK Behavior](decisions/nonrecordingspan-and-no-sdk-behavior.md)
- [ ] [Trace Context Interaction](decisions/trace-context-interaction.md)

### Trace SDK — Provider & Configuration
- [ ] [TracerProvider SDK: Configuration](decisions/tracerprovider-sdk-configuration.md)
- [ ] [TracerProvider SDK: Shutdown & ForceFlush](decisions/tracerprovider-sdk-shutdown-and-forceflush.md)

### Trace SDK — Sampling
- [ ] [Sampler Interface & ShouldSample](decisions/sampler-interface-and-shouldsample.md)
- [ ] [Built-in Samplers](decisions/built-in-samplers.md)

### Trace SDK — Span Creation & Storage
- [ ] [ID Generation](decisions/id-generation.md)
- [ ] [SDK Span Creation Flow](decisions/sdk-span-creation-flow.md)
- [ ] [Span Storage & ETS Design](decisions/span-storage-and-ets-design.md)

### Trace SDK — Span Processors
- [ ] [SpanProcessor Interface](decisions/spanprocessor-interface.md)
- [ ] [SimpleSpanProcessor](decisions/simplespanprocessor.md)
- [ ] [BatchSpanProcessor](decisions/batchspanprocessor.md)

### Trace SDK — Span Exporters
- [ ] [SpanExporter Interface](decisions/spanexporter-interface.md)
- [ ] [Console (stdout) Exporter](decisions/console-stdout-exporter.md)

### Propagators
- [ ] [TextMapPropagator Interface](decisions/textmappropagator-interface.md)
- [ ] [Composite Propagator & Global Registration](decisions/composite-propagator-and-global-registration.md)
- [ ] [W3C TraceContext Propagator](decisions/w3c-tracecontext-propagator.md)

### Baggage
- [ ] [Baggage API](decisions/baggage-api.md)
- [ ] [W3C Baggage Propagator](decisions/w3c-baggage-propagator.md)

### OTP Infrastructure
- [ ] [Supervision Tree Structure](decisions/supervision-tree-structure.md)
- [ ] [Application Boot Order](decisions/application-boot-order.md)

## Phase 2: OTLP HTTP Exporter
- [ ] [OTLP HTTP Exporter](decisions/otlp-http-exporter.md)
- [ ] [Exporter Packaging Strategy](decisions/exporter-packaging-strategy.md)

## Phase 3: Metrics
- [ ] [Metrics API](decisions/metrics-api.md)
- [ ] [Metrics SDK](decisions/metrics-sdk.md)

## Phase 4: Logs, Baggage, OTLP gRPC
- [ ] [Logs API & SDK](decisions/logs-api-and-sdk.md)
- [ ] [:logger Integration](decisions/logger-integration.md)
- [ ] [OTLP gRPC Exporter](decisions/otlp-grpc-exporter.md)
