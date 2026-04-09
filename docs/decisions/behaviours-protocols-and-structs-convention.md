# Behaviours, Protocols, and Structs Convention

## Question

When to use Elixir behaviours, protocols, and plain structs for OTel interfaces? Which pattern best maps Provider/Processor/Exporter/Sampler interfaces to BEAM primitives?

## Decision

TBD — decide for each concept by category.

### Reference: opentelemetry-erlang Patterns

Analysis of how [opentelemetry-erlang](https://github.com/open-telemetry/opentelemetry-erlang) implements each concept, to inform our Elixir design decisions.

### Provider

Stateful singletons that manage configuration and lifecycle.

| Concept | erlang | Our decision |
|---------|--------|--------------|
| TracerProvider | `gen_server` + `persistent_term` cache | TBD |
| MeterProvider | `gen_server` + ETS tables | TBD |
| LoggerProvider | `gen_statem` (OTP `:logger` integration) | TBD |

### Factory/Handle

Lightweight handles returned by providers. Not processes — just data used on the hot path.

| Concept | erlang | Our decision |
|---------|--------|--------------|
| Tracer | `record` as `{module, record}` tuple, cached in `persistent_term` | TBD |
| Meter | `record` as `{module, record}` tuple, holds ETS refs | TBD |
| Logger | N/A (OTP `:logger` used directly) | TBD |
| InstrumentationScope | `record` shared across all signals | TBD |

### Interface — Trace

Pluggable components users can implement or swap.

| Concept | erlang | Callbacks | Our decision |
|---------|--------|-----------|--------------|
| SpanProcessor | `behaviour` | `on_start`, `on_end`, `force_flush` | TBD |
| SpanExporter | `behaviour` | `init`, `export`, `shutdown` | TBD |
| Sampler | `behaviour` | `setup`, `description`, `should_sample` | TBD |
| IdGenerator | `behaviour` + default impl in same module | `generate_trace_id`, `generate_span_id` | TBD |

### Interface — Metrics

| Concept | erlang | Callbacks | Our decision |
|---------|--------|-----------|--------------|
| MetricExporter | `behaviour` | `init`, `export`, `shutdown` | TBD |
| MetricProducer | `behaviour` | `init`, `produce_batch` | TBD |
| Aggregation | `behaviour` | `init`, `aggregate`, `collect` | TBD |
| MetricReader | `gen_server` (concrete, not behaviour) | — | TBD |
| ExemplarFilter | plain functions (fun reference) | — | TBD |
| ExemplarReservoir | module+state record (duck-typed, no formal behaviour) | — | TBD |

### Interface — Logs

| Concept | erlang | Callbacks | Our decision |
|---------|--------|-----------|--------------|
| LogRecordProcessor | N/A (merged into `otel_log_handler`) | — | TBD |
| LogRecordExporter | `behaviour` | `init`, `export`, `shutdown` | TBD |

### Interface — Propagator

| Concept | erlang | Callbacks | Our decision |
|---------|--------|-----------|--------------|
| TextMapPropagator | `behaviour` | `inject`, `extract`, `fields` | TBD |
| Getter/Setter | plain functions (fun reference) | — | TBD |

### Instruments

All instruments share a single `#instrument{}` record with a `kind` atom. Each instrument type is a thin wrapper module.

| Concept | erlang | Our decision |
|---------|--------|--------------|
| Counter | wrapper module + `#instrument{kind: counter}` | TBD |
| AsyncCounter | wrapper module + `#instrument{kind: observable_counter}` | TBD |
| Histogram | wrapper module + `#instrument{kind: histogram}` | TBD |
| Gauge | N/A (not implemented in erlang) | TBD |
| AsyncGauge | wrapper module + `#instrument{kind: observable_gauge}` | TBD |
| UpDownCounter | wrapper module + `#instrument{kind: updown_counter}` | TBD |
| AsyncUpDownCounter | wrapper module + `#instrument{kind: observable_updowncounter}` | TBD |

### Data Structure — Trace

| Concept | erlang | Location | Our decision |
|---------|--------|----------|--------------|
| Span | `record` | SDK | TBD |
| SpanContext | `record` | API | TBD |
| TraceState | `record` (wraps kv list) | API | TBD |
| NonRecordingSpan | — (encoded in SpanContext) | API | TBD |
| Link | `record` (in wrapper with limits) | SDK | TBD |
| Event | `record` (in wrapper with limits) | SDK | TBD |
| SpanLimits | `record` (with defaults) | SDK | TBD |
| Status | `record` (`code` + `message`) | API | TBD |

### Data Structure — Common

| Concept | erlang | Location | Our decision |
|---------|--------|----------|--------------|
| Resource | `record` | SDK | TBD |
| Attributes | `record` wrapping `map` (with limits/dropped tracking) | API | TBD |
| AnyValue | type union (no dedicated structure) | API | TBD |
| Context | `map` in process dictionary | API | TBD |
| Baggage | `map` stored inside Context | API | TBD |

### Data Structure — Metrics

| Concept | erlang | Location | Our decision |
|---------|--------|----------|--------------|
| Measurement | `record` | SDK | TBD |
| Exemplar | `record` | SDK | TBD |
| View | `record` | SDK | TBD |

### Data Structure — Logs

| Concept | erlang | Location | Our decision |
|---------|--------|----------|--------------|
| LogRecord | `logger:log_event()` map (no custom type) | SDK | TBD |
| ReadableLogRecord | N/A | SDK | TBD |
| ReadWriteLogRecord | N/A | SDK | TBD |
| LogRecordLimits | N/A (not implemented) | SDK | TBD |

### Enum / Constant

| Concept | erlang | Our decision |
|---------|--------|--------------|
| StatusCode | atom + macro (`unset`, `ok`, `error`) | TBD |
| SpanKind | atom + macro (`internal`, `server`, `client`, `producer`, `consumer`) | TBD |
| ExportResult | bare atoms (`success`, `failed_not_retryable`, `failed_retryable`) | TBD |
| AggregationTemporality | atom + macro (`temporality_delta`, `temporality_cumulative`) | TBD |

### Built-in Implementation

Concrete implementations of the interfaces above.

| Concept | erlang | Interface | Our decision |
|---------|--------|-----------|--------------|
| SimpleSpanProcessor | `gen_statem` | SpanProcessor | TBD |
| BatchSpanProcessor | `gen_statem` + ETS double-buffering | SpanProcessor | TBD |
| AlwaysOnSampler | plain module (stateless) | Sampler | TBD |
| AlwaysOffSampler | plain module (stateless) | Sampler | TBD |
| TraceIdRatioBased | plain module (stateless) | Sampler | TBD |
| ParentBased | plain module | Sampler | TBD |
| ConsoleSpanExporter | plain module (`io:format`) | SpanExporter | TBD |
| ConsoleMetricExporter | plain module | MetricExporter | TBD |
| ConsoleLogExporter | plain module | LogRecordExporter | TBD |
| W3C TraceContext | module impl `TextMapPropagator` | TextMapPropagator | TBD |
| W3C Baggage | module impl `TextMapPropagator` | TextMapPropagator | TBD |
| CompositePropagator | `foldl` over propagator list | TextMapPropagator | TBD |
| SimpleLogRecordProcessor | — | LogRecordProcessor | TBD |
| BatchLogRecordProcessor | `gen_statem` | LogRecordProcessor | TBD |
| PeriodicExportingMetricReader | — | MetricReader | TBD |
| Sum aggregation | module impl `Aggregation` + ETS | Aggregation | TBD |
| LastValue aggregation | module impl `Aggregation` + ETS | Aggregation | TBD |
| ExplicitBucketHistogram | module impl `Aggregation` + counters | Aggregation | TBD |
| Drop aggregation | module impl `Aggregation` (no-op) | Aggregation | TBD |

## Compliance
