# OpenTelemetry Specification v1.55.0 Compliance

Stable specification items only. Organized by implementation order aligned with [Tech Spec](tech-spec.md) phases. Check items as they are implemented.

## Phase 1: Foundation

### Attributes

- [ ] Support primitive attribute types: string, boolean, integer (signed 64-bit), double (IEEE 754)
- [ ] Support homogeneous arrays of primitive types
- [ ] Support byte array attributes
- [ ] Attribute keys must be non-null, non-empty strings
- [ ] Preserve case sensitivity of attribute keys
- [ ] Configurable attribute count limit (default: 128)
- [ ] Configurable attribute value length limit (default: no limit)
- [ ] Truncate string/byte array values exceeding length limit
- [ ] Discard attributes exceeding count limit
- [ ] Apply value length limit recursively to nested arrays and maps

### Context API

- [ ] Context is immutable; write operations return new Context
- [ ] Create a key: accept key name, return opaque key object
- [ ] Get value: accept Context and key, return associated value
- [ ] Set value: accept Context, key, and value, return new Context
- [ ] Get current Context (for implicit propagation)
- [ ] Attach Context: accept Context, return token for detachment
- [ ] Detach Context: accept token, restore previous Context

### Propagators — TextMapPropagator

- [ ] Inject: accept Context and carrier, set propagation fields
- [ ] Extract: accept Context and carrier, return new Context with extracted values
- [ ] Extract must not throw on unparseable values
- [ ] Fields: return list of propagation keys used during injection
- [ ] TextMapGetter: Keys, Get (first value), GetAll methods
- [ ] TextMapSetter: Set method, preserve casing for case-insensitive protocols

### Composite Propagator

- [ ] Combine multiple propagators into one
- [ ] Invoke component propagators in registration order

### Global Propagators

- [ ] Provide get/set for global propagator
- [ ] Default to no-op propagator unless explicitly configured

### W3C TraceContext Propagator

- [ ] Parse and validate `traceparent` header per W3C Trace Context Level 2
- [ ] Parse and validate `tracestate` header
- [ ] Inject valid `traceparent` header
- [ ] Inject valid `tracestate` header (unless empty)
- [ ] Propagate TraceId (16 bytes), SpanId (8 bytes), TraceFlags, TraceState

### W3C Baggage Propagator

- [ ] Implement TextMapPropagator for W3C Baggage specification
- [ ] On conflict, new pair takes precedence

### Baggage API

- [ ] Get value by name (return value or null)
- [ ] Get all name/value pairs (order not significant)
- [ ] Set value: accept name, value (strings), optional metadata
- [ ] Remove value by name (return new Baggage without entry)
- [ ] Each name associates with exactly one value
- [ ] Names and values are valid UTF-8 strings; names must be non-empty
- [ ] Case-sensitive treatment of names and values
- [ ] Baggage container is immutable
- [ ] Metadata: opaque string wrapper with no semantic meaning

### Baggage — Context Interaction

- [ ] Extract Baggage from Context
- [ ] Insert Baggage into Context
- [ ] Retrieve and set active Baggage (for implicit propagation)
- [ ] Remove all Baggage entries from a Context

### Baggage — Propagation

- [ ] W3C Baggage TextMapPropagator implementation
- [ ] On conflict, new pair takes precedence

### Baggage — Functional Without SDK

- [ ] API must be fully functional without an installed SDK

### Resource

- [ ] Create Resource from attributes
- [ ] Accept optional schema_url
- [ ] Merge two Resources (updating resource values take precedence)
- [ ] Schema URL merge rules (empty, matching, conflicting)
- [ ] Support empty Resource creation
- [ ] Associate Resource with TracerProvider at creation (immutable after)
- [ ] Associate Resource with MeterProvider at creation (immutable after)
- [ ] Associate Resource with LoggerProvider at creation (immutable after)
- [ ] Provide default Resource with SDK attributes (telemetry.sdk.*)
- [ ] Extract `OTEL_RESOURCE_ATTRIBUTES` env var and merge (user-provided takes priority)
- [ ] Extract `OTEL_SERVICE_NAME` env var
- [ ] Resource detection must not fail on detection errors
- [ ] Resource attributes are immutable after creation
- [ ] Provide read-only attribute retrieval

## Phase 2: Traces

### Trace API — TracerProvider

- [ ] Provide function to get a Tracer
- [ ] Accept `name` parameter (required)
- [ ] Accept optional `version` parameter
- [ ] Accept optional `schema_url` parameter
- [ ] Accept optional `attributes` parameter (instrumentation scope)
- [ ] Return working Tracer even for invalid names (no null/exception)
- [ ] Provide global default TracerProvider mechanism
- [ ] Configuration changes apply to already-returned Tracers
- [ ] Thread-safe for concurrent use

### Trace API — Tracer

- [ ] Provide function to create new Spans
- [ ] Provide Enabled API returning boolean
- [ ] Thread-safe for concurrent use

### Trace API — SpanContext

- [ ] TraceId: 16-byte array, at least one non-zero byte
- [ ] SpanId: 8-byte array, at least one non-zero byte
- [ ] TraceFlags: Sampled flag, Random flag
- [ ] TraceState: immutable key-value list per W3C spec
- [ ] IsRemote: boolean indicating remote origin
- [ ] Provide TraceId/SpanId as hex (lowercase) and binary
- [ ] IsValid: true when TraceId and SpanId are both non-zero
- [ ] IsRemote: true when propagated from remote parent

### Trace API — TraceState

- [ ] Get value for key
- [ ] Add new key/value pair (returns new TraceState)
- [ ] Update existing key/value pair (returns new TraceState)
- [ ] Delete key/value pair (returns new TraceState)
- [ ] Validate input parameters; never return invalid data
- [ ] All mutations return new TraceState (immutable)

### Trace API — Span Creation

- [ ] Spans created only via Tracer (no other API)
- [ ] Accept span name (required)
- [ ] Accept parent Context or root span indication
- [ ] Accept SpanKind (default: Internal)
- [ ] Accept initial Attributes
- [ ] Accept Links (ordered sequence)
- [ ] Accept start timestamp (default: current time)
- [ ] Root span option generates new TraceId
- [ ] Child span TraceId matches parent
- [ ] Child inherits parent TraceState by default
- [ ] Preserve order of Links

### Trace API — SpanKind

- [ ] SERVER
- [ ] CLIENT
- [ ] PRODUCER
- [ ] CONSUMER
- [ ] INTERNAL (default)

### Trace API — Span Operations

- [ ] GetContext: return SpanContext (same for entire lifetime)
- [ ] IsRecording: return boolean; false after End
- [ ] SetAttribute: set single attribute (overwrite on same key)
- [ ] SetAttributes: set multiple attributes at once (optional)
- [ ] AddEvent: record event with name, timestamp, and attributes
- [ ] Events preserve recording order
- [ ] AddLink: add Link after span creation (SpanContext + attributes)
- [ ] SetStatus: accept StatusCode (Unset, Ok, Error) and optional description
- [ ] Status Ok is final (ignore subsequent changes)
- [ ] Setting Unset is ignored
- [ ] Status order: Ok > Error > Unset
- [ ] UpdateName: update span name
- [ ] End: signal span completion; ignore subsequent calls
- [ ] End accepts optional explicit end timestamp
- [ ] End must not block calling thread (no blocking I/O)
- [ ] End does not affect child spans
- [ ] End does not inactivate span in any Context
- [ ] RecordException: specialized AddEvent for exceptions (optional per language)

### Trace API — No-Op Behavior

- [ ] Without SDK: API is no-op
- [ ] Return non-recording Span with SpanContext from parent Context
- [ ] If no parent: return Span with all-zero IDs

### Trace SDK — TracerProvider

- [ ] Specify Resource at creation
- [ ] Configure SpanProcessors, IdGenerator, SpanLimits, Sampler
- [ ] Shutdown: call once, invoke Shutdown on all processors
- [ ] Shutdown: return success/failure/timeout indication
- [ ] After shutdown: return no-op Tracers
- [ ] ForceFlush: invoke ForceFlush on all registered SpanProcessors
- [ ] ForceFlush: return success/failure/timeout indication
- [ ] Thread-safe for Tracer creation, ForceFlush, Shutdown

### Trace SDK — Span Limits

- [ ] `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT` — per-span attribute value length
- [ ] `OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT` — max span attributes (default: 128)
- [ ] `OTEL_SPAN_EVENT_COUNT_LIMIT` — max span events (default: 128)
- [ ] `OTEL_SPAN_LINK_COUNT_LIMIT` — max span links (default: 128)
- [ ] `OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT` — max attributes per event (default: 128)
- [ ] `OTEL_LINK_ATTRIBUTE_COUNT_LIMIT` — max attributes per link (default: 128)
- [ ] Log message when limits cause discards (at most once per span)

### Trace SDK — IdGenerator

- [ ] Default: randomly generate TraceId (16 bytes) and SpanId (8 bytes)
- [ ] Provide mechanism for custom IdGenerator

### Trace SDK — Samplers

- [ ] AlwaysOn: return RECORD_AND_SAMPLE; description "AlwaysOnSampler"
- [ ] AlwaysOff: return DROP; description "AlwaysOffSampler"
- [ ] TraceIdRatioBased: deterministic hash of TraceId; ignore parent SampledFlag
- [ ] TraceIdRatioBased: lower probability is subset of higher probability
- [ ] TraceIdRatioBased: description "TraceIdRatioBased{RATIO}"
- [ ] ParentBased: required `root` sampler parameter
- [ ] ParentBased: optional `remoteParentSampled` (default: AlwaysOn)
- [ ] ParentBased: optional `remoteParentNotSampled` (default: AlwaysOff)
- [ ] ParentBased: optional `localParentSampled` (default: AlwaysOn)
- [ ] ParentBased: optional `localParentNotSampled` (default: AlwaysOff)
- [ ] Sampler ShouldSample and GetDescription must be thread-safe

### Trace SDK — SpanProcessor

- [ ] OnStart: called synchronously when span starts; must not block/throw
- [ ] OnEnd: called after span ends with readable span
- [ ] Shutdown: called once during SDK shutdown
- [ ] ForceFlush: ensure span export within timeout
- [ ] All methods must be thread-safe

#### Simple SpanProcessor

- [ ] Pass finished spans to SpanExporter immediately
- [ ] Synchronize Export calls (no concurrent invocation)

#### Batch SpanProcessor

- [ ] Create batches of spans for export
- [ ] Synchronize Export calls (no concurrent invocation)
- [ ] Export on scheduledDelayMillis interval (default: 5000)
- [ ] Export on maxExportBatchSize threshold (default: 512)
- [ ] Export on ForceFlush call
- [ ] maxQueueSize configuration (default: 2048)
- [ ] exportTimeoutMillis configuration (default: 30000)
- [ ] `OTEL_BSP_SCHEDULE_DELAY` env var (default: 5000)
- [ ] `OTEL_BSP_EXPORT_TIMEOUT` env var (default: 30000)
- [ ] `OTEL_BSP_MAX_QUEUE_SIZE` env var (default: 2048)
- [ ] `OTEL_BSP_MAX_EXPORT_BATCH_SIZE` env var (default: 512)

### Trace SDK — SpanExporter

- [ ] Export: accept batch of spans, return Success or Failure
- [ ] Export must not be called concurrently for same instance
- [ ] Export must not block indefinitely (reasonable timeout)
- [ ] Shutdown: called once; subsequent Export returns Failure
- [ ] Shutdown must not block indefinitely
- [ ] ForceFlush: hint to complete prior exports promptly
- [ ] ForceFlush and Shutdown must be thread-safe

### Console Exporter — Spans

- [ ] Output spans to stdout/console
- [ ] Output format is implementation-defined
- [ ] Document as debugging/learning tool, not for production
- [ ] Default pairing with Simple SpanProcessor

## Phase 3: OTLP Exporters (Traces)

### OTLP Exporter — Common Configuration

- [ ] `OTEL_EXPORTER_OTLP_ENDPOINT` — base endpoint URL
- [ ] Per-signal endpoint overrides (`*_TRACES_ENDPOINT`, `*_METRICS_ENDPOINT`, `*_LOGS_ENDPOINT`)
- [ ] `OTEL_EXPORTER_OTLP_PROTOCOL` — grpc, http/protobuf, http/json (default: http/protobuf)
- [ ] Per-signal protocol overrides
- [ ] `OTEL_EXPORTER_OTLP_HEADERS` — key-value pairs as request headers
- [ ] Per-signal header overrides
- [ ] `OTEL_EXPORTER_OTLP_COMPRESSION` — gzip or none
- [ ] Per-signal compression overrides
- [ ] `OTEL_EXPORTER_OTLP_TIMEOUT` — per-batch timeout (default: 10s)
- [ ] Per-signal timeout overrides
- [ ] `OTEL_EXPORTER_OTLP_CERTIFICATE` — TLS certificate file
- [ ] Per-signal certificate overrides
- [ ] `OTEL_EXPORTER_OTLP_CLIENT_KEY` — mTLS client private key
- [ ] `OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE` — mTLS client certificate
- [ ] Signal-specific options take precedence over general options
- [ ] Emit User-Agent header (e.g., OTel-OTLP-Exporter-Elixir/VERSION)

### OTLP Protocol — Encoding

- [ ] Binary Protobuf encoding (Proto3)
- [ ] JSON Protobuf encoding: traceId/spanId as hex (not base64), enum as integers, lowerCamelCase keys
- [ ] Receivers must ignore unknown fields in JSON

### OTLP/HTTP Exporter

- [ ] Default endpoint: http://localhost:4318
- [ ] Append signal-specific paths to base endpoint: /v1/traces, /v1/metrics, /v1/logs
- [ ] Per-signal endpoint used as-is (no path appending)
- [ ] HTTP POST requests for sending telemetry
- [ ] Support binary Protobuf (Content-Type: application/x-protobuf)
- [ ] Support JSON Protobuf (Content-Type: application/json) — optional but recommended
- [ ] Support gzip compression (Content-Encoding: gzip)
- [ ] Handle HTTP 200 OK (success)
- [ ] Handle partial success (HTTP 200 with partial_success field)
- [ ] Handle HTTP 400 Bad Request (non-retryable)
- [ ] Handle retryable status codes: 429, 502, 503, 504
- [ ] Respect Retry-After header on 429/503
- [ ] Exponential backoff with jitter for retries
- [ ] Must not modify URL beyond specified rules

### OTLP/gRPC Exporter

- [ ] Default endpoint: http://localhost:4317
- [ ] Unary RPC calls with Export*ServiceRequest messages
- [ ] Support gzip compression
- [ ] Handle success: Export*ServiceResponse
- [ ] Handle partial success (partial_success field)
- [ ] Handle retryable gRPC status: UNAVAILABLE (with optional RetryInfo)
- [ ] Handle non-retryable gRPC status: INVALID_ARGUMENT
- [ ] Retryable gRPC codes: CANCELLED, DEADLINE_EXCEEDED, ABORTED, OUT_OF_RANGE, UNAVAILABLE, DATA_LOSS
- [ ] Non-retryable gRPC codes: UNKNOWN, INVALID_ARGUMENT, NOT_FOUND, ALREADY_EXISTS, PERMISSION_DENIED, UNAUTHENTICATED, FAILED_PRECONDITION, INTERNAL, UNIMPLEMENTED
- [ ] Exponential backoff with jitter for retries
- [ ] https scheme takes precedence over insecure setting
- [ ] Configurable concurrent request count
- [ ] `OTEL_EXPORTER_OTLP_INSECURE` — transport security (default: false)

## Phase 4: Metrics

### Metrics API — MeterProvider

- [ ] Provide function to get/create a Meter
- [ ] Accept `name` parameter (required)
- [ ] Accept optional `version` parameter
- [ ] Accept optional `schema_url` parameter
- [ ] Accept optional `attributes` parameter (instrumentation scope)
- [ ] Return working Meter even for invalid names
- [ ] Provide global default MeterProvider mechanism
- [ ] Thread-safe for concurrent use

### Metrics API — Meter

- [ ] Provide functions to create all instrument types
- [ ] Thread-safe for concurrent use

### Metrics API — Instrument General

- [ ] Instrument identity: name, kind, unit, description
- [ ] Name: starts with alpha, max 255 chars, case-insensitive
- [ ] Name: allows alphanumeric, underscore, period, hyphen, forward slash
- [ ] Unit: optional, case-sensitive, max 63 ASCII chars
- [ ] Description: optional, supports BMP Unicode, at least 1023 chars

### Metrics API — Synchronous Instruments

#### Counter

- [ ] Create with name, optional unit, description, advisory params
- [ ] Add: accept non-negative increment value and optional attributes
- [ ] Enabled API returning boolean

#### UpDownCounter

- [ ] Create with name, optional unit, description, advisory params
- [ ] Add: accept positive or negative value and optional attributes
- [ ] Enabled API returning boolean

#### Histogram

- [ ] Create with name, optional unit, description, advisory params
- [ ] Record: accept non-negative value and optional attributes
- [ ] Enabled API returning boolean

#### Gauge

- [ ] Create with name, optional unit, description, advisory params
- [ ] Record: accept value (absolute current) and optional attributes
- [ ] Enabled API returning boolean

### Metrics API — Asynchronous Instruments

#### Observable Counter

- [ ] Create with name, optional unit, description, advisory params, callbacks
- [ ] Callback reports absolute monotonically increasing value
- [ ] Support callback registration/unregistration after creation

#### Observable UpDownCounter

- [ ] Create with name, optional unit, description, advisory params, callbacks
- [ ] Callback reports absolute additive value
- [ ] Support callback registration/unregistration after creation

#### Observable Gauge

- [ ] Create with name, optional unit, description, advisory params, callbacks
- [ ] Callback reports non-additive value
- [ ] Support callback registration/unregistration after creation

### Metrics API — Callback Requirements

- [ ] Callbacks evaluated exactly once per collection per instrument
- [ ] Observations from single callback treated as same instant
- [ ] Should be reentrant safe
- [ ] Should not make duplicate observations (same attributes)

### Metrics SDK — MeterProvider

- [ ] Specify Resource at creation
- [ ] Configure MetricExporters, MetricReaders, Views
- [ ] Support multiple MetricReader registration (independent operation)
- [ ] Shutdown: call once, invoke Shutdown on all MetricReaders and MetricExporters
- [ ] Shutdown: return success/failure/timeout; subsequent meter requests return no-op
- [ ] ForceFlush: invoke on all registered MetricReaders
- [ ] Thread-safe for meter creation, ForceFlush, Shutdown
- [ ] Return working Meter for invalid names (log the issue)

### Metrics SDK — Meter

- [ ] Validate instrument names on creation
- [ ] Emit error for invalid instrument names
- [ ] Handle duplicate instrument registration (warn, aggregate identical)
- [ ] Case-insensitive name handling: return first-seen casing
- [ ] Null/missing unit and description treated as empty string
- [ ] Advisory parameters: View config takes precedence
- [ ] Instrument Enabled: false when MeterConfig disabled or all Views use Drop

### Metrics SDK — Views

- [ ] Instrument selection criteria: name (exact/wildcard), type, unit, meter_name, meter_version, meter_schema_url
- [ ] Single asterisk matches all instruments
- [ ] Selection criteria are additive (AND logic)
- [ ] Stream configuration: name override, description override
- [ ] Stream configuration: attribute key allow-list/exclude-list
- [ ] Stream configuration: aggregation specification
- [ ] Stream configuration: exemplar_reservoir, aggregation_cardinality_limit
- [ ] No Views registered: apply default aggregation per instrument kind
- [ ] Registered Views: independently apply each matching View
- [ ] No matching View: enable with default aggregation
- [ ] Views not merged; warn on conflicting metric identities

### Metrics SDK — Aggregation

- [ ] Drop aggregation: ignore all measurements
- [ ] Default aggregation: select per instrument kind
- [ ] Sum aggregation: arithmetic sum of measurements
- [ ] Last Value aggregation: last measurement with timestamp
- [ ] Explicit Bucket Histogram: count, sum, optional min/max
- [ ] Explicit Bucket Histogram default boundaries: [0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000]
- [ ] Explicit Bucket Histogram RecordMinMax (default: true)
- [ ] Buckets: exclusive of lower bound, inclusive of upper bound

#### Default Aggregation Mapping

- [ ] Counter / Observable Counter -> Sum (monotonic)
- [ ] UpDownCounter / Observable UpDownCounter -> Sum (non-monotonic)
- [ ] Gauge / Observable Gauge -> Last Value
- [ ] Histogram -> Explicit Bucket Histogram

### Metrics SDK — Temporal Aggregation

- [ ] Cumulative temporality: consistent start timestamp across all collection intervals
- [ ] Cumulative: data points persist regardless of new measurements
- [ ] Delta temporality: start timestamp advances between collections
- [ ] Delta: only data points with measurements since previous collection

### Metrics SDK — Cardinality Limits

- [ ] View-specific limit takes precedence
- [ ] MetricReader default limit applies second
- [ ] Default cardinality limit: 2000
- [ ] Enforce after attribute filtering
- [ ] Overflow aggregator with attribute `otel.metric.overflow=true`
- [ ] Every measurement reflected exactly once (no double-counting/dropping)

### Metrics SDK — Exemplars

- [ ] Exemplar sampling on by default
- [ ] ExemplarFilter: AlwaysOn, AlwaysOff, TraceBased (default)
- [ ] Configurable ExemplarReservoir per View
- [ ] ExemplarReservoir: offer (value, attributes, context, timestamp)
- [ ] ExemplarReservoir: collect (respect aggregation temporality)
- [ ] Return attributes not already in metric data point
- [ ] SimpleFixedSizeExemplarReservoir: uniform sampling (default for most)
- [ ] AlignedHistogramBucketExemplarReservoir: one per bucket (default for histograms)
- [ ] Thread-safe ExemplarReservoir methods

### Metrics SDK — MetricReader

- [ ] Configure: exporter, default aggregation, output temporality, cardinality limit
- [ ] Optional: MetricProducers, MetricFilter
- [ ] Collect: gather metrics from SDK and MetricProducers
- [ ] Collect: trigger asynchronous instrument callbacks
- [ ] Collect: return success/failure/timeout
- [ ] Shutdown: call once; subsequent Collect not allowed
- [ ] Support multiple MetricReaders on same MeterProvider (independent)
- [ ] MetricReader must not be registered on multiple MeterProviders

#### Periodic Exporting MetricReader

- [ ] exportIntervalMillis configuration (default: 60000)
- [ ] exportTimeoutMillis configuration (default: 30000)
- [ ] Collect metrics on configurable interval
- [ ] Synchronize exporter calls (no concurrent invocation)
- [ ] ForceFlush: collect and export immediately

### Metrics SDK — MetricExporter (Push)

- [ ] Export: accept metrics, return Success or Failure
- [ ] Export must not be called concurrently for same instance
- [ ] Export must not block indefinitely
- [ ] Shutdown: call once; subsequent Export returns Failure
- [ ] Shutdown must not block indefinitely
- [ ] ForceFlush: hint to complete prior exports
- [ ] ForceFlush and Shutdown must be thread-safe

### Console Exporter — Metrics

- [ ] Output metrics to stdout/console
- [ ] Output format is implementation-defined
- [ ] Document as debugging/learning tool, not for production
- [ ] Default temporality: Cumulative for all instrument kinds
- [ ] Pair with Periodic Exporting MetricReader (default interval: 10000ms)

## Phase 5: Logs, Baggage, OTLP gRPC

### Logs API — LoggerProvider

- [ ] Provide function to get a Logger
- [ ] Accept `name` parameter (required)
- [ ] Accept optional `version`, `schema_url`, `attributes` parameters
- [ ] Provide global default LoggerProvider mechanism
- [ ] Thread-safe for concurrent use

### Logs API — Logger

- [ ] Provide function to emit LogRecord
- [ ] Accept optional: Timestamp, Observed Timestamp, Context, Severity Number, Severity Text, Body, Attributes, Event Name
- [ ] Provide Enabled API returning boolean
- [ ] Enabled accepts optional: Context, Severity Number, Event Name
- [ ] Thread-safe for concurrent use

### Logs SDK — LoggerProvider

- [ ] Specify Resource at creation
- [ ] Configure LogRecordProcessors
- [ ] Updated configuration applies to all existing Loggers
- [ ] Shutdown: call once; subsequent Logger retrieval not allowed
- [ ] Shutdown: invoke Shutdown on all registered LogRecordProcessors
- [ ] ForceFlush: invoke ForceFlush on all registered LogRecordProcessors
- [ ] Thread-safe for Logger creation, ForceFlush, Shutdown

### Logs SDK — Logger

- [ ] Set ObservedTimestamp to current time if unspecified
- [ ] Apply exception semantic conventions to exception attributes
- [ ] User-provided attributes must not be overwritten by exception-derived attributes
- [ ] Thread-safe for all methods

### Logs SDK — LogRecord Limits

- [ ] Configurable attribute count limit
- [ ] Configurable attribute value length limit
- [ ] `OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT` env var
- [ ] `OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT` env var (default: 128)
- [ ] Log message when attributes discarded (at most once per LogRecord)

### Logs SDK — LogRecordProcessor

- [ ] OnEmit: called synchronously; must not block/throw
- [ ] LogRecord mutations visible to next registered processors
- [ ] Shutdown: call once; subsequent OnEmit not allowed
- [ ] ForceFlush: complete or abort within timeout
- [ ] Thread-safe for all methods

#### Simple LogRecordProcessor

- [ ] Pass finished LogRecords to LogRecordExporter immediately
- [ ] Synchronize Export calls (no concurrent invocation)

#### Batch LogRecordProcessor

- [ ] Create batches of LogRecords for export
- [ ] Synchronize Export calls (no concurrent invocation)
- [ ] maxQueueSize configuration (default: 2048)
- [ ] scheduledDelayMillis configuration (default: 1000)
- [ ] exportTimeoutMillis configuration (default: 30000)
- [ ] maxExportBatchSize configuration (default: 512)
- [ ] `OTEL_BLRP_SCHEDULE_DELAY` env var (default: 1000)
- [ ] `OTEL_BLRP_EXPORT_TIMEOUT` env var (default: 30000)
- [ ] `OTEL_BLRP_MAX_QUEUE_SIZE` env var (default: 2048)
- [ ] `OTEL_BLRP_MAX_EXPORT_BATCH_SIZE` env var (default: 512)

### Logs SDK — LogRecordExporter

- [ ] Export: accept batch of LogRecords, return Success or Failure
- [ ] Export must not be called concurrently for same instance
- [ ] Export must not block indefinitely
- [ ] Shutdown: call once; subsequent Export returns Failure
- [ ] ForceFlush and Shutdown must be thread-safe

### Console Exporter — Logs

- [ ] Output LogRecords to stdout/console
- [ ] Output format is implementation-defined
- [ ] Document as debugging/learning tool, not for production
- [ ] Default pairing with Simple LogRecordProcessor

## Environment Variables

General SDK configuration. Applied across all phases.

- [ ] `OTEL_SDK_DISABLED` — disable SDK for all signals (default: false)
- [ ] `OTEL_RESOURCE_ATTRIBUTES` — key-value pairs for resource attributes
- [ ] `OTEL_SERVICE_NAME` — set service.name resource attribute
- [ ] `OTEL_LOG_LEVEL` — SDK internal logger level (default: info)
- [ ] `OTEL_PROPAGATORS` — comma-separated propagator list (default: tracecontext,baggage)
- [ ] `OTEL_TRACES_SAMPLER` — sampler for traces (default: parentbased_always_on)
- [ ] `OTEL_TRACES_SAMPLER_ARG` — sampler argument
- [ ] `OTEL_TRACES_EXPORTER` — trace exporter (default: otlp)
- [ ] `OTEL_METRICS_EXPORTER` — metrics exporter (default: otlp)
- [ ] `OTEL_LOGS_EXPORTER` — logs exporter (default: otlp)
- [ ] `OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT` — global attribute value length limit
- [ ] `OTEL_ATTRIBUTE_COUNT_LIMIT` — global attribute count limit (default: 128)
