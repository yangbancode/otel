# Design Decisions (BEAM/OTP)

Decisions specific to implementing the OpenTelemetry SDK on the BEAM VM. These are not part of the OTel specification but are required to map spec concepts to Erlang/OTP primitives.

Each decision has its own document under [decisions/](decisions/) with related [compliance](compliance.md) items linked. When all linked compliance items are checked, the implementation for that decision is complete.

Items are ordered by implementation sequence — completing them top to bottom produces a working system.

## Phase 1: Traces

### Foundation
- [x] [Package Structure & Module Namespacing](decisions/package-structure-and-module-namespacing.md)
- [x] [Minimum Elixir Version](decisions/minimum-elixir-version.md)
- [ ] [Error Handling Strategy](decisions/error-handling-strategy.md)
- [ ] [SDK Internal Logging Strategy](decisions/sdk-internal-logging-strategy.md)
- [ ] [Configuration & Environment Variable System](decisions/configuration-and-environment-variable-system.md)
- [ ] [Supervision Tree Structure](decisions/supervision-tree-structure.md)
- [ ] [Application Boot Order](decisions/application-boot-order.md)

### Common
- [ ] [AnyValue Type System](decisions/anyvalue-type-system.md)
- [ ] [Attribute & Attribute Collections](decisions/attribute-and-attribute-collections.md)
- [ ] [Attribute Limits](decisions/attribute-limits.md)

### Context
- [ ] [Context Data Structure & Operations](decisions/context-data-structure-and-operations.md)
- [ ] [Context Attach/Detach & Process-Local Storage](decisions/context-attach-detach-and-process-local-storage.md)
- [ ] [Cross-Process Context Passing](decisions/cross-process-context-passing.md)

### Semantic Conventions
- [ ] [Semantic Conventions Code Generation](decisions/semantic-conventions-code-generation.md)

### Resource
- [ ] [Resource Creation & Merge](decisions/resource-creation-and-merge.md)
- [ ] [Resource Detection & Environment Variables](decisions/resource-detection-and-environment-variables.md)

### Trace API
- [ ] [SpanContext Struct](decisions/spancontext-struct.md)
- [ ] [SpanContext Validation & Remote](decisions/spancontext-validation-and-remote.md)
- [ ] [TraceState](decisions/tracestate.md)
- [ ] [TracerProvider API](decisions/tracerprovider-api.md)
- [ ] [Tracer & InstrumentationScope](decisions/tracer-and-instrumentationscope.md)
- [ ] [Span Interface & Lifecycle](decisions/span-interface-and-lifecycle.md)
- [ ] [Span Creation](decisions/span-creation.md)
- [ ] [Span Operations: Attributes & Events](decisions/span-operations-attributes-and-events.md)
- [ ] [Span Operations: Links, Status, End](decisions/span-operations-links-status-end.md)
- [ ] [Span Operations: RecordException](decisions/span-operations-record-exception.md)
- [ ] [NonRecordingSpan & No-SDK Behavior](decisions/nonrecordingspan-and-no-sdk-behavior.md)
- [ ] [Trace Context Interaction](decisions/trace-context-interaction.md)

### Trace SDK
- [ ] [TracerProvider SDK: Configuration](decisions/tracerprovider-sdk-configuration.md)
- [ ] [TracerProvider SDK: Shutdown & ForceFlush](decisions/tracerprovider-sdk-shutdown-and-forceflush.md)
- [ ] [Span Limits](decisions/span-limits.md)
- [ ] [ID Generation](decisions/id-generation.md)
- [ ] [Sampler Interface & ShouldSample](decisions/sampler-interface-and-shouldsample.md)
- [ ] [Built-in Samplers](decisions/built-in-samplers.md)
- [ ] [Span Storage & ETS Design](decisions/span-storage-and-ets-design.md)
- [ ] [SDK Span Creation Flow](decisions/sdk-span-creation-flow.md)

### Span Processors & Exporters
- [ ] [SpanExporter Interface](decisions/spanexporter-interface.md)
- [ ] [Console (stdout) Exporter](decisions/console-stdout-exporter.md)
- [ ] [SpanProcessor Interface](decisions/spanprocessor-interface.md)
- [ ] [SimpleSpanProcessor](decisions/simplespanprocessor.md)
- [ ] [BatchSpanProcessor](decisions/batchspanprocessor.md)

### Propagators
- [ ] [TextMapPropagator Interface](decisions/textmappropagator-interface.md)
- [ ] [Composite Propagator & Global Registration](decisions/composite-propagator-and-global-registration.md)
- [ ] [W3C TraceContext Propagator](decisions/w3c-tracecontext-propagator.md)

### Baggage
- [ ] [Baggage API](decisions/baggage-api.md)
- [ ] [W3C Baggage Propagator](decisions/w3c-baggage-propagator.md)

## Phase 2: OTLP HTTP Exporter
- [ ] [Exporter Packaging Strategy](decisions/exporter-packaging-strategy.md)
- [ ] [OTLP HTTP Exporter](decisions/otlp-http-exporter.md)
- [ ] [Protobuf Encoding & Code Generation](decisions/protobuf-encoding-and-code-generation.md)
- [ ] [OTLP Retry, Backoff & Throttling](decisions/otlp-retry-backoff-and-throttling.md)

## Phase 3: Metrics

### Metrics API
- [ ] [MeterProvider & Meter API](decisions/meterprovider-and-meter-api.md)
- [ ] [Synchronous Instruments](decisions/synchronous-instruments.md)
- [ ] [Asynchronous Instruments & Callbacks](decisions/asynchronous-instruments-and-callbacks.md)

### Metrics SDK
- [ ] [MeterProvider SDK](decisions/meterprovider-sdk.md)
- [ ] [Meter: Instrument Registration & Validation](decisions/meter-instrument-registration-and-validation.md)
- [ ] [View System](decisions/view-system.md)
- [ ] [Aggregation Types](decisions/aggregation-types.md)
- [ ] [Async Observations & Cardinality Limits](decisions/async-observations-and-cardinality-limits.md)
- [ ] [Exemplar System](decisions/exemplar-system.md)
- [ ] [MetricReader & Periodic Exporting](decisions/metricreader-and-periodic-exporting.md)
- [ ] [MetricExporter & MetricProducer](decisions/metricexporter-and-metricproducer.md)

## Phase 4: Logs, OTLP gRPC

### Logs API
- [ ] [Logs API](decisions/logs-api.md)

### Logs SDK
- [ ] [Logs SDK](decisions/logs-sdk.md)

### :logger Integration
- [ ] [:logger Integration](decisions/logger-integration.md)

### OTLP gRPC Exporter
- [ ] [OTLP gRPC Exporter](decisions/otlp-grpc-exporter.md)

## Release
- [ ] [Hex.pm Publishing Strategy](decisions/hex-publishing-strategy.md)
