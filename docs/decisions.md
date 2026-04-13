# Design Decisions (BEAM/OTP)

Decisions specific to implementing the OpenTelemetry SDK on the BEAM VM. These are not part of the OTel specification but are required to map spec concepts to Erlang/OTP primitives.

Each decision has its own document under [decisions/](decisions/) with related [compliance](compliance.md) items linked. When all linked compliance items are checked, the implementation for that decision is complete.

Items are ordered by implementation sequence — completing them top to bottom produces a working system.

## Foundation

- [x] [Package Structure & Module Namespacing](decisions/package-structure-and-module-namespacing.md)
- [x] [Minimum Elixir Version](decisions/minimum-elixir-version.md)
- [x] [Logging Convention](decisions/logging-convention.md)
- [x] [GitHub Actions CI](decisions/github-actions-ci.md)
- [x] [Application & Supervision Tree](decisions/application-and-supervision.md)

## Phase 1: Traces

### Context
- [x] [Context](decisions/context-data-structure-and-operations.md)

### Trace API
- [x] [SpanContext](decisions/spancontext-struct.md)
- [x] [TraceState](decisions/tracestate.md)
- [x] [TracerProvider API](decisions/tracerprovider-api.md)
- [x] [Tracer & InstrumentationScope](decisions/tracer-and-instrumentationscope.md)
- [x] [Span Interface & Lifecycle](decisions/span-interface-and-lifecycle.md)
- [x] [Span Creation](decisions/span-creation.md)

### Trace SDK
- [x] [TracerProvider SDK: Configuration](decisions/tracerprovider-sdk-configuration.md)
- [x] [TracerProvider SDK: Shutdown & ForceFlush](decisions/tracerprovider-sdk-shutdown-and-forceflush.md)
- [x] [Span Limits](decisions/span-limits.md)
- [x] [ID Generation](decisions/id-generation.md)
- [x] [Sampler Interface & ShouldSample](decisions/sampler-interface-and-shouldsample.md)
- [x] [Built-in Samplers](decisions/built-in-samplers.md)
- [x] [Span Storage & ETS Design](decisions/span-storage-and-ets-design.md)
- [x] [SDK Span Creation Flow](decisions/sdk-span-creation-flow.md)

### Span Processors & Exporters
- [x] [SpanProcessor Interface](decisions/spanprocessor-interface.md)
- [x] [SpanExporter Interface](decisions/spanexporter-interface.md)
- [x] [SimpleSpanProcessor](decisions/simplespanprocessor.md)
- [x] [Console Exporter](decisions/console-exporter.md)
- [x] [BatchSpanProcessor](decisions/batchspanprocessor.md)
- [x] [Span Operations](decisions/span-operations.md)

### Propagators
- [x] [TextMapPropagator Interface](decisions/textmappropagator-interface.md)
- [x] [Composite Propagator & Global Registration](decisions/composite-propagator-and-global-registration.md)
- [x] [W3C TraceContext Propagator](decisions/w3c-tracecontext-propagator.md)

### Baggage
- [x] [Baggage API](decisions/baggage-api.md)
- [x] [W3C Baggage Propagator](decisions/w3c-baggage-propagator.md)

### Environment Variables
- [x] [Trace Environment Variables](decisions/trace-environment-variables.md)

## Phase 2: OTLP Exporters

### Resource
- [ ] [Resource Creation & Merge](decisions/resource-creation-and-merge.md)
- [ ] [Resource Detection & Environment Variables](decisions/resource-detection-and-environment-variables.md)

### OTLP
- [ ] [Protobuf Encoding & Code Generation](decisions/protobuf-encoding-and-code-generation.md)
- [ ] [OTLP HTTP Exporter](decisions/otlp-http-exporter.md)
- [ ] [OTLP Retry, Backoff & Throttling](decisions/otlp-retry-backoff-and-throttling.md)
- [ ] [OTLP gRPC Exporter](decisions/otlp-grpc-exporter.md)

### Environment Variables
- [ ] [OTLP Environment Variables](decisions/otlp-environment-variables.md)

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

### Environment Variables
- [ ] [Metrics Environment Variables](decisions/metrics-environment-variables.md)

## Phase 4: Logs

### Logs API
- [ ] [Logs API](decisions/logs-api.md)

### Logs SDK
- [ ] [Logs SDK](decisions/logs-sdk.md)

### :logger Integration
- [ ] [:logger Integration](decisions/logger-integration.md)

### Environment Variables
- [ ] [Logs Environment Variables](decisions/logs-environment-variables.md)

## Phase 5: Semantic Conventions
- [ ] [Semantic Conventions Code Generation](decisions/semantic-conventions-code-generation.md)

## Finalization
- [ ] [Error Handling](decisions/error-handling.md)
- [ ] [hex.pm Publishing Strategy](decisions/hex-publishing-strategy.md)
