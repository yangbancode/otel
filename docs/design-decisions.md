# Design Decisions (BEAM/OTP)

Decisions specific to implementing the OpenTelemetry SDK on the BEAM VM. These are not part of the OTel specification but are required to map spec concepts to Erlang/OTP primitives.

Each decision has its own document under [decisions/](decisions/) with related [compliance](compliance.md) items linked. When all linked compliance items are checked, the implementation for that decision is complete.

- Status: 🔲 not started / 🚧 in progress / ✅ done

## Phase 1: Traces

### Foundation

| # | Decision | Status |
|---|----------|--------|
| [DD-01](decisions/dd-01.md) | Package Structure & Module Namespacing | 🔲 |
| [DD-02](decisions/dd-02.md) | Behaviours, Protocols, and Structs Convention | 🔲 |
| [DD-03](decisions/dd-03.md) | Error Handling Strategy | 🔲 |
| [DD-04](decisions/dd-04.md) | Configuration & Environment Variable System | 🔲 |

### Common

| # | Decision | Status |
|---|----------|--------|
| [DD-05](decisions/dd-05.md) | AnyValue Type System | 🔲 |
| [DD-06](decisions/dd-06.md) | Attribute & Attribute Collections | 🔲 |
| [DD-07](decisions/dd-07.md) | Attribute Limits | 🔲 |

### Context

| # | Decision | Status |
|---|----------|--------|
| [DD-08](decisions/dd-08.md) | Context Data Structure & Operations | 🔲 |
| [DD-09](decisions/dd-09.md) | Context Attach/Detach & Process-Local Storage | 🔲 |
| [DD-10](decisions/dd-10.md) | Cross-Process Context Passing | 🔲 |

### Resource

| # | Decision | Status |
|---|----------|--------|
| [DD-11](decisions/dd-11.md) | Resource Creation & Merge | 🔲 |
| [DD-12](decisions/dd-12.md) | Resource Detection & Environment Variables | 🔲 |

### Trace API — Provider & Tracer

| # | Decision | Status |
|---|----------|--------|
| [DD-13](decisions/dd-13.md) | TracerProvider API | 🔲 |
| [DD-14](decisions/dd-14.md) | Tracer & InstrumentationScope | 🔲 |

### Trace API — SpanContext

| # | Decision | Status |
|---|----------|--------|
| [DD-15](decisions/dd-15.md) | SpanContext Struct | 🔲 |
| [DD-16](decisions/dd-16.md) | SpanContext Validation & Remote | 🔲 |
| [DD-17](decisions/dd-17.md) | TraceState | 🔲 |

### Trace API — Span

| # | Decision | Status |
|---|----------|--------|
| [DD-18](decisions/dd-18.md) | Span Interface & Lifecycle | 🔲 |
| [DD-19](decisions/dd-19.md) | Span Creation | 🔲 |
| [DD-20](decisions/dd-20.md) | Span Operations: Attributes & Events | 🔲 |
| [DD-21](decisions/dd-21.md) | Span Operations: Links, Status, End | 🔲 |
| [DD-22](decisions/dd-22.md) | Span Operations: RecordException | 🔲 |
| [DD-23](decisions/dd-23.md) | NonRecordingSpan & No-SDK Behavior | 🔲 |
| [DD-24](decisions/dd-24.md) | Trace Context Interaction | 🔲 |

### Trace SDK — Provider & Configuration

| # | Decision | Status |
|---|----------|--------|
| [DD-25](decisions/dd-25.md) | TracerProvider SDK: Configuration | 🔲 |
| [DD-26](decisions/dd-26.md) | TracerProvider SDK: Shutdown & ForceFlush | 🔲 |

### Trace SDK — Sampling

| # | Decision | Status |
|---|----------|--------|
| [DD-27](decisions/dd-27.md) | Sampler Interface & ShouldSample | 🔲 |
| [DD-28](decisions/dd-28.md) | Built-in Samplers | 🔲 |

### Trace SDK — Span Creation & Storage

| # | Decision | Status |
|---|----------|--------|
| [DD-29](decisions/dd-29.md) | ID Generation | 🔲 |
| [DD-30](decisions/dd-30.md) | SDK Span Creation Flow | 🔲 |
| [DD-31](decisions/dd-31.md) | Span Storage & ETS Design | 🔲 |

### Trace SDK — Span Processors

| # | Decision | Status |
|---|----------|--------|
| [DD-32](decisions/dd-32.md) | SpanProcessor Interface | 🔲 |
| [DD-33](decisions/dd-33.md) | SimpleSpanProcessor | 🔲 |
| [DD-34](decisions/dd-34.md) | BatchSpanProcessor | 🔲 |

### Trace SDK — Span Exporters

| # | Decision | Status |
|---|----------|--------|
| [DD-35](decisions/dd-35.md) | SpanExporter Interface | 🔲 |
| [DD-36](decisions/dd-36.md) | Console (stdout) Exporter | 🔲 |

### Propagators

| # | Decision | Status |
|---|----------|--------|
| [DD-37](decisions/dd-37.md) | TextMapPropagator Interface | 🔲 |
| [DD-38](decisions/dd-38.md) | Composite Propagator & Global Registration | 🔲 |
| [DD-39](decisions/dd-39.md) | W3C TraceContext Propagator | 🔲 |

### Baggage

| # | Decision | Status |
|---|----------|--------|
| [DD-40](decisions/dd-40.md) | Baggage API | 🔲 |
| [DD-41](decisions/dd-41.md) | W3C Baggage Propagator | 🔲 |

### OTP Infrastructure

| # | Decision | Status |
|---|----------|--------|
| [DD-42](decisions/dd-42.md) | Supervision Tree Structure | 🔲 |
| [DD-43](decisions/dd-43.md) | Application Boot Order | 🔲 |

## Phase 2: OTLP HTTP Exporter

| # | Decision | Status |
|---|----------|--------|
| [DD-44](decisions/dd-44.md) | OTLP HTTP Exporter | 🔲 |
| [DD-50](decisions/dd-50.md) | Exporter Packaging Strategy | 🔲 |

## Phase 3: Metrics

| # | Decision | Status |
|---|----------|--------|
| [DD-45](decisions/dd-45.md) | Metrics API | 🔲 |
| [DD-46](decisions/dd-46.md) | Metrics SDK | 🔲 |

## Phase 4: Logs, Baggage, OTLP gRPC

| # | Decision | Status |
|---|----------|--------|
| [DD-47](decisions/dd-47.md) | Logs API & SDK | 🔲 |
| [DD-48](decisions/dd-48.md) | :logger Integration | 🔲 |
| [DD-49](decisions/dd-49.md) | OTLP gRPC Exporter | 🔲 |
