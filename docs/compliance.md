# OpenTelemetry Specification v1.55.0 Compliance

Stable specification items only. Check items as they are implemented.

## Common

> Ref: [common/README.md](references/opentelemetry-specification-v1.55.0/common/README.md)

### Attributes

- [ ] Support primitive attribute types: string, boolean, integer (signed 64-bit), double (IEEE 754) — [L42-L44](references/opentelemetry-specification-v1.55.0/common/README.md#L42)
- [ ] Support homogeneous arrays of primitive types — [L45-L46](references/opentelemetry-specification-v1.55.0/common/README.md#L45)
- [ ] Support byte array attributes — [L47](references/opentelemetry-specification-v1.55.0/common/README.md#L47)
- [ ] Attribute keys must be non-null, non-empty strings — [L185](references/opentelemetry-specification-v1.55.0/common/README.md#L185)
- [ ] Preserve case sensitivity of attribute keys — [L186](references/opentelemetry-specification-v1.55.0/common/README.md#L186)
- [ ] Configurable attribute count limit (default: 128) — [L305](references/opentelemetry-specification-v1.55.0/common/README.md#L305)
- [ ] Configurable attribute value length limit (default: no limit) — [L306](references/opentelemetry-specification-v1.55.0/common/README.md#L306)
- [ ] Truncate string/byte array values exceeding length limit — [L262-L267](references/opentelemetry-specification-v1.55.0/common/README.md#L262)
- [ ] Discard attributes exceeding count limit — [L275-L282](references/opentelemetry-specification-v1.55.0/common/README.md#L275)
- [ ] Apply value length limit recursively to nested arrays and maps — [L268-L273](references/opentelemetry-specification-v1.55.0/common/README.md#L268)

## Context

> Ref: [context/README.md](references/opentelemetry-specification-v1.55.0/context/README.md)

### Context API

- [ ] Context is immutable; write operations return new Context — [L37-L39](references/opentelemetry-specification-v1.55.0/context/README.md#L37)
- [ ] Create a key: accept key name, return opaque key object — [L63-L67](references/opentelemetry-specification-v1.55.0/context/README.md#L63)
- [ ] Get value: accept Context and key, return associated value — [L74-L79](references/opentelemetry-specification-v1.55.0/context/README.md#L74)
- [ ] Set value: accept Context, key, and value, return new Context — [L86-L92](references/opentelemetry-specification-v1.55.0/context/README.md#L86)
- [ ] Get current Context (for implicit propagation) — [L103](references/opentelemetry-specification-v1.55.0/context/README.md#L103)
- [ ] Attach Context: accept Context, return token for detachment — [L109-L114](references/opentelemetry-specification-v1.55.0/context/README.md#L109)
- [ ] Detach Context: accept token, restore previous Context — [L119-L136](references/opentelemetry-specification-v1.55.0/context/README.md#L119)

## API Propagators

> Ref: [context/api-propagators.md](references/opentelemetry-specification-v1.55.0/context/api-propagators.md)

### TextMapPropagator

- [ ] Inject: accept Context and carrier, set propagation fields — [L87-L96](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L87)
- [ ] Extract: accept Context and carrier, return new Context with extracted values — [L98-L112](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L98)
- [ ] Extract must not throw on unparseable values — [L101-L103](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L101)
- [ ] Fields: return list of propagation keys used during injection — [L133-L149](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L133)
- [ ] TextMapGetter: Keys, Get (first value), GetAll methods — [L207-L249](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L207)
- [ ] TextMapSetter: Set method, preserve casing for case-insensitive protocols — [L165-L183](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L165)

### Composite Propagator

- [ ] Combine multiple propagators into one — [L259-L266](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L259)
- [ ] Invoke component propagators in registration order — [L266](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L266)

### Global Propagators

- [ ] Provide get/set for global propagator — [L334-L348](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L334)
- [ ] Default to no-op propagator unless explicitly configured — [L322-L326](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L322)

### W3C TraceContext Propagator

- [ ] Parse and validate `traceparent` header per W3C Trace Context Level 2 — [L355-L362](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L355)
- [ ] Parse and validate `tracestate` header — [L363-L368](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L363)
- [ ] Inject valid `traceparent` header — [L370-L374](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L370)
- [ ] Inject valid `tracestate` header (unless empty) — [L375-L377](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L375)
- [ ] Propagate TraceId (16 bytes), SpanId (8 bytes), TraceFlags, TraceState — [L378-L384](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L378)

### W3C Baggage Propagator

- [ ] Implement TextMapPropagator for W3C Baggage specification — [L390-L396](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L390)
- [ ] On conflict, new pair takes precedence — [L397-L399](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L397)

## Baggage

> Ref: [baggage/api.md](references/opentelemetry-specification-v1.55.0/baggage/api.md)

### Baggage API

- [ ] Get value by name (return value or null) — [L37-L41](references/opentelemetry-specification-v1.55.0/baggage/api.md#L37)
- [ ] Get all name/value pairs (order not significant) — [L43-L47](references/opentelemetry-specification-v1.55.0/baggage/api.md#L43)
- [ ] Set value: accept name, value (strings), optional metadata — [L49-L57](references/opentelemetry-specification-v1.55.0/baggage/api.md#L49)
- [ ] Remove value by name (return new Baggage without entry) — [L59-L63](references/opentelemetry-specification-v1.55.0/baggage/api.md#L59)
- [ ] Each name associates with exactly one value — [L23-L25](references/opentelemetry-specification-v1.55.0/baggage/api.md#L23)
- [ ] Names and values are valid UTF-8 strings; names must be non-empty — [L27-L30](references/opentelemetry-specification-v1.55.0/baggage/api.md#L27)
- [ ] Case-sensitive treatment of names and values — [L31-L32](references/opentelemetry-specification-v1.55.0/baggage/api.md#L31)
- [ ] Baggage container is immutable — [L33-L35](references/opentelemetry-specification-v1.55.0/baggage/api.md#L33)
- [ ] Metadata: opaque string wrapper with no semantic meaning — [L65-L75](references/opentelemetry-specification-v1.55.0/baggage/api.md#L65)

### Context Interaction

- [ ] Extract Baggage from Context — [L77-L82](references/opentelemetry-specification-v1.55.0/baggage/api.md#L77)
- [ ] Insert Baggage into Context — [L84-L89](references/opentelemetry-specification-v1.55.0/baggage/api.md#L84)
- [ ] Retrieve and set active Baggage (for implicit propagation) — [L91-L95](references/opentelemetry-specification-v1.55.0/baggage/api.md#L91)
- [ ] Remove all Baggage entries from a Context — [L97-L101](references/opentelemetry-specification-v1.55.0/baggage/api.md#L97)

### Propagation

- [ ] W3C Baggage TextMapPropagator implementation — [L103-L109](references/opentelemetry-specification-v1.55.0/baggage/api.md#L103)
- [ ] On conflict, new pair takes precedence — [L110-L112](references/opentelemetry-specification-v1.55.0/baggage/api.md#L110)

### Functional Without SDK

- [ ] API must be fully functional without an installed SDK — [L113-L116](references/opentelemetry-specification-v1.55.0/baggage/api.md#L113)

## Resource

> Ref: [resource/sdk.md](references/opentelemetry-specification-v1.55.0/resource/sdk.md)

### Resource SDK

- [ ] Create Resource from attributes — [L18-L25](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L18)
- [ ] Accept optional schema_url — [L26-L30](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L26)
- [ ] Merge two Resources (updating resource values take precedence) — [L84-L98](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L84)
- [ ] Schema URL merge rules (empty, matching, conflicting) — [L99-L115](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L99)
- [ ] Support empty Resource creation — [L32-L35](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L32)
- [ ] Associate Resource with TracerProvider at creation (immutable after) — [L63-L66](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L63)
- [ ] Associate Resource with MeterProvider at creation (immutable after) — [L67-L70](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L67)
- [ ] Associate Resource with LoggerProvider at creation (immutable after) — [L71-L74](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L71)
- [ ] Provide default Resource with SDK attributes (telemetry.sdk.*) — [L37-L55](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L37)
- [ ] Extract `OTEL_RESOURCE_ATTRIBUTES` env var and merge (user-provided takes priority) — [L56-L60](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L56)
- [ ] Extract `OTEL_SERVICE_NAME` env var — [L61-L62](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L61)
- [ ] Resource detection must not fail on detection errors — [L117-L122](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L117)
- [ ] Resource attributes are immutable after creation — [L75-L78](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L75)
- [ ] Provide read-only attribute retrieval — [L79-L82](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L79)

## Trace API

> Ref: [trace/api.md](references/opentelemetry-specification-v1.55.0/trace/api.md)

### TracerProvider

- [ ] Provide function to get a Tracer — [L72-L78](references/opentelemetry-specification-v1.55.0/trace/api.md#L72)
- [ ] Accept `name` parameter (required) — [L79-L90](references/opentelemetry-specification-v1.55.0/trace/api.md#L79)
- [ ] Accept optional `version` parameter — [L91-L92](references/opentelemetry-specification-v1.55.0/trace/api.md#L91)
- [ ] Accept optional `schema_url` parameter — [L93-L96](references/opentelemetry-specification-v1.55.0/trace/api.md#L93)
- [ ] Accept optional `attributes` parameter (instrumentation scope) — [L97-L102](references/opentelemetry-specification-v1.55.0/trace/api.md#L97)
- [ ] Return working Tracer even for invalid names (no null/exception) — [L103-L110](references/opentelemetry-specification-v1.55.0/trace/api.md#L103)
- [ ] Provide global default TracerProvider mechanism — [L62-L70](references/opentelemetry-specification-v1.55.0/trace/api.md#L62)
- [ ] Configuration changes apply to already-returned Tracers — [L111-L116](references/opentelemetry-specification-v1.55.0/trace/api.md#L111)
- [ ] Thread-safe for concurrent use — [L117-L119](references/opentelemetry-specification-v1.55.0/trace/api.md#L117)

### Tracer

- [ ] Provide function to create new Spans — [L128-L134](references/opentelemetry-specification-v1.55.0/trace/api.md#L128)
- [ ] Provide Enabled API returning boolean — [L136-L148](references/opentelemetry-specification-v1.55.0/trace/api.md#L136)
- [ ] Thread-safe for concurrent use — [L149-L151](references/opentelemetry-specification-v1.55.0/trace/api.md#L149)

### SpanContext

- [ ] TraceId: 16-byte array, at least one non-zero byte — [L153-L161](references/opentelemetry-specification-v1.55.0/trace/api.md#L153)
- [ ] SpanId: 8-byte array, at least one non-zero byte — [L162-L170](references/opentelemetry-specification-v1.55.0/trace/api.md#L162)
- [ ] TraceFlags: Sampled flag, Random flag — [L171-L185](references/opentelemetry-specification-v1.55.0/trace/api.md#L171)
- [ ] TraceState: immutable key-value list per W3C spec — [L186-L197](references/opentelemetry-specification-v1.55.0/trace/api.md#L186)
- [ ] IsRemote: boolean indicating remote origin — [L218-L225](references/opentelemetry-specification-v1.55.0/trace/api.md#L218)
- [ ] Provide TraceId/SpanId as hex (lowercase) and binary — [L198-L206](references/opentelemetry-specification-v1.55.0/trace/api.md#L198)
- [ ] IsValid: true when TraceId and SpanId are both non-zero — [L207-L217](references/opentelemetry-specification-v1.55.0/trace/api.md#L207)
- [ ] IsRemote: true when propagated from remote parent — [L218-L225](references/opentelemetry-specification-v1.55.0/trace/api.md#L218)

### TraceState

- [ ] Get value for key — [L226-L234](references/opentelemetry-specification-v1.55.0/trace/api.md#L226)
- [ ] Add new key/value pair (returns new TraceState) — [L235-L244](references/opentelemetry-specification-v1.55.0/trace/api.md#L235)
- [ ] Update existing key/value pair (returns new TraceState) — [L245-L254](references/opentelemetry-specification-v1.55.0/trace/api.md#L245)
- [ ] Delete key/value pair (returns new TraceState) — [L255-L264](references/opentelemetry-specification-v1.55.0/trace/api.md#L255)
- [ ] Validate input parameters; never return invalid data — [L265-L271](references/opentelemetry-specification-v1.55.0/trace/api.md#L265)
- [ ] All mutations return new TraceState (immutable) — [L272-L276](references/opentelemetry-specification-v1.55.0/trace/api.md#L272)

### Span Creation

- [ ] Spans created only via Tracer (no other API) — [L278-L284](references/opentelemetry-specification-v1.55.0/trace/api.md#L278)
- [ ] Accept span name (required) — [L285-L292](references/opentelemetry-specification-v1.55.0/trace/api.md#L285)
- [ ] Accept parent Context or root span indication — [L293-L319](references/opentelemetry-specification-v1.55.0/trace/api.md#L293)
- [ ] Accept SpanKind (default: Internal) — [L320-L327](references/opentelemetry-specification-v1.55.0/trace/api.md#L320)
- [ ] Accept initial Attributes — [L328-L338](references/opentelemetry-specification-v1.55.0/trace/api.md#L328)
- [ ] Accept Links (ordered sequence) — [L339-L367](references/opentelemetry-specification-v1.55.0/trace/api.md#L339)
- [ ] Accept start timestamp (default: current time) — [L368-L373](references/opentelemetry-specification-v1.55.0/trace/api.md#L368)
- [ ] Root span option generates new TraceId — [L306-L310](references/opentelemetry-specification-v1.55.0/trace/api.md#L306)
- [ ] Child span TraceId matches parent — [L311-L315](references/opentelemetry-specification-v1.55.0/trace/api.md#L311)
- [ ] Child inherits parent TraceState by default — [L316-L319](references/opentelemetry-specification-v1.55.0/trace/api.md#L316)
- [ ] Preserve order of Links — [L356-L360](references/opentelemetry-specification-v1.55.0/trace/api.md#L356)

### SpanKind

- [ ] SERVER — [L380-L384](references/opentelemetry-specification-v1.55.0/trace/api.md#L380)
- [ ] CLIENT — [L385-L389](references/opentelemetry-specification-v1.55.0/trace/api.md#L385)
- [ ] PRODUCER — [L390-L394](references/opentelemetry-specification-v1.55.0/trace/api.md#L390)
- [ ] CONSUMER — [L395-L399](references/opentelemetry-specification-v1.55.0/trace/api.md#L395)
- [ ] INTERNAL (default) — [L400-L404](references/opentelemetry-specification-v1.55.0/trace/api.md#L400)

### Span Operations

- [ ] GetContext: return SpanContext (same for entire lifetime) — [L406-L414](references/opentelemetry-specification-v1.55.0/trace/api.md#L406)
- [ ] IsRecording: return boolean; false after End — [L415-L432](references/opentelemetry-specification-v1.55.0/trace/api.md#L415)
- [ ] SetAttribute: set single attribute (overwrite on same key) — [L433-L455](references/opentelemetry-specification-v1.55.0/trace/api.md#L433)
- [ ] SetAttributes: set multiple attributes at once (optional) — [L456-L463](references/opentelemetry-specification-v1.55.0/trace/api.md#L456)
- [ ] AddEvent: record event with name, timestamp, and attributes — [L464-L492](references/opentelemetry-specification-v1.55.0/trace/api.md#L464)
- [ ] Events preserve recording order — [L488-L492](references/opentelemetry-specification-v1.55.0/trace/api.md#L488)
- [ ] AddLink: add Link after span creation (SpanContext + attributes) — [L493-L525](references/opentelemetry-specification-v1.55.0/trace/api.md#L493)
- [ ] SetStatus: accept StatusCode (Unset, Ok, Error) and optional description — [L526-L567](references/opentelemetry-specification-v1.55.0/trace/api.md#L526)
- [ ] Status Ok is final (ignore subsequent changes) — [L558-L562](references/opentelemetry-specification-v1.55.0/trace/api.md#L558)
- [ ] Setting Unset is ignored — [L563-L565](references/opentelemetry-specification-v1.55.0/trace/api.md#L563)
- [ ] Status order: Ok > Error > Unset — [L553-L557](references/opentelemetry-specification-v1.55.0/trace/api.md#L553)
- [ ] UpdateName: update span name — [L568-L580](references/opentelemetry-specification-v1.55.0/trace/api.md#L568)
- [ ] End: signal span completion; ignore subsequent calls — [L581-L615](references/opentelemetry-specification-v1.55.0/trace/api.md#L581)
- [ ] End accepts optional explicit end timestamp — [L600-L605](references/opentelemetry-specification-v1.55.0/trace/api.md#L600)
- [ ] End must not block calling thread (no blocking I/O) — [L606-L608](references/opentelemetry-specification-v1.55.0/trace/api.md#L606)
- [ ] End does not affect child spans — [L609-L611](references/opentelemetry-specification-v1.55.0/trace/api.md#L609)
- [ ] End does not inactivate span in any Context — [L612-L615](references/opentelemetry-specification-v1.55.0/trace/api.md#L612)
- [ ] RecordException: specialized AddEvent for exceptions (optional per language) — [L616-L653](references/opentelemetry-specification-v1.55.0/trace/api.md#L616)

### No-Op Behavior

- [ ] Without SDK: API is no-op — [L660-L668](references/opentelemetry-specification-v1.55.0/trace/api.md#L660)
- [ ] Return non-recording Span with SpanContext from parent Context — [L669-L680](references/opentelemetry-specification-v1.55.0/trace/api.md#L669)
- [ ] If no parent: return Span with all-zero IDs — [L681-L685](references/opentelemetry-specification-v1.55.0/trace/api.md#L681)

## Trace SDK

> Ref: [trace/sdk.md](references/opentelemetry-specification-v1.55.0/trace/sdk.md)

### TracerProvider

- [ ] Specify Resource at creation — [L93-L97](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L93)
- [ ] Configure SpanProcessors, IdGenerator, SpanLimits, Sampler — [L98-L108](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L98)
- [ ] Shutdown: call once, invoke Shutdown on all processors — [L142-L170](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L142)
- [ ] Shutdown: return success/failure/timeout indication — [L162-L165](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L162)
- [ ] After shutdown: return no-op Tracers — [L166-L170](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L166)
- [ ] ForceFlush: invoke ForceFlush on all registered SpanProcessors — [L172-L192](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L172)
- [ ] ForceFlush: return success/failure/timeout indication — [L185-L188](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L185)
- [ ] Thread-safe for Tracer creation, ForceFlush, Shutdown — [L193-L198](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L193)

### Span Limits

- [ ] `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT` — per-span attribute value length — [L130](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L130)
- [ ] `OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT` — max span attributes (default: 128) — [L131](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L131)
- [ ] `OTEL_SPAN_EVENT_COUNT_LIMIT` — max span events (default: 128) — [L132](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L132)
- [ ] `OTEL_SPAN_LINK_COUNT_LIMIT` — max span links (default: 128) — [L133](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L133)
- [ ] `OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT` — max attributes per event (default: 128) — [L134](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L134)
- [ ] `OTEL_LINK_ATTRIBUTE_COUNT_LIMIT` — max attributes per link (default: 128) — [L135](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L135)
- [ ] Log message when limits cause discards (at most once per span) — [L218-L224](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L218)

### IdGenerator

- [ ] Default: randomly generate TraceId (16 bytes) and SpanId (8 bytes) — [L243-L253](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L243)
- [ ] Provide mechanism for custom IdGenerator — [L254-L258](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L254)

### Samplers

- [ ] AlwaysOn: return RECORD_AND_SAMPLE; description "AlwaysOnSampler" — [L372-L377](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L372)
- [ ] AlwaysOff: return DROP; description "AlwaysOffSampler" — [L378-L383](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L378)
- [ ] TraceIdRatioBased: deterministic hash of TraceId; ignore parent SampledFlag — [L384-L406](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L384)
- [ ] TraceIdRatioBased: lower probability is subset of higher probability — [L400-L403](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L400)
- [ ] TraceIdRatioBased: description "TraceIdRatioBased{RATIO}" — [L404-L406](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L404)
- [ ] ParentBased: required `root` sampler parameter — [L407-L420](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L407)
- [ ] ParentBased: optional `remoteParentSampled` (default: AlwaysOn) — [L421-L424](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L421)
- [ ] ParentBased: optional `remoteParentNotSampled` (default: AlwaysOff) — [L425-L428](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L425)
- [ ] ParentBased: optional `localParentSampled` (default: AlwaysOn) — [L429-L432](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L429)
- [ ] ParentBased: optional `localParentNotSampled` (default: AlwaysOff) — [L433-L436](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L433)
- [ ] Sampler ShouldSample and GetDescription must be thread-safe — [L437-L441](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L437)

### SpanProcessor

- [ ] OnStart: called synchronously when span starts; must not block/throw — [L449-L464](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L449)
- [ ] OnEnd: called after span ends with readable span — [L465-L477](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L465)
- [ ] Shutdown: called once during SDK shutdown — [L478-L497](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L478)
- [ ] ForceFlush: ensure span export within timeout — [L498-L519](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L498)
- [ ] All methods must be thread-safe — [L520-L525](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L520)

### Simple SpanProcessor

- [ ] Pass finished spans to SpanExporter immediately — [L532-L540](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L532)
- [ ] Synchronize Export calls (no concurrent invocation) — [L541-L543](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L541)

### Batch SpanProcessor

- [ ] Create batches of spans for export — [L549-L560](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L549)
- [ ] Synchronize Export calls (no concurrent invocation) — [L561-L563](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L561)
- [ ] Export on scheduledDelayMillis interval (default: 5000) — [L565-L567](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L565)
- [ ] Export on maxExportBatchSize threshold (default: 512) — [L568-L570](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L568)
- [ ] Export on ForceFlush call — [L571-L573](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L571)
- [ ] maxQueueSize configuration (default: 2048) — [L574-L576](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L574)
- [ ] exportTimeoutMillis configuration (default: 30000) — [L577-L579](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L577)
- [ ] `OTEL_BSP_SCHEDULE_DELAY` env var (default: 5000) — [L137](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L137)
- [ ] `OTEL_BSP_EXPORT_TIMEOUT` env var (default: 30000) — [L138](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L138)
- [ ] `OTEL_BSP_MAX_QUEUE_SIZE` env var (default: 2048) — [L139](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L139)
- [ ] `OTEL_BSP_MAX_EXPORT_BATCH_SIZE` env var (default: 512) — [L140](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L140)

### SpanExporter

- [ ] Export: accept batch of spans, return Success or Failure — [L590-L626](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L590)
- [ ] Export must not be called concurrently for same instance — [L596-L597](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L596)
- [ ] Export must not block indefinitely (reasonable timeout) — [L607-L609](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L607)
- [ ] Shutdown: called once; subsequent Export returns Failure — [L656-L678](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L656)
- [ ] Shutdown must not block indefinitely — [L672-L674](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L672)
- [ ] ForceFlush: hint to complete prior exports promptly — [L638-L654](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L638)
- [ ] ForceFlush and Shutdown must be thread-safe — [L679-L685](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L679)

## Trace Exporters

### Console (stdout)

> Ref: [trace/sdk_exporters/stdout.md](references/opentelemetry-specification-v1.55.0/trace/sdk_exporters/stdout.md)

- [ ] Output spans to stdout/console — [L9-L10](references/opentelemetry-specification-v1.55.0/trace/sdk_exporters/stdout.md#L9)
- [ ] Output format is implementation-defined — [L12-L13](references/opentelemetry-specification-v1.55.0/trace/sdk_exporters/stdout.md#L12)
- [ ] Document as debugging/learning tool, not for production — [L16-L18](references/opentelemetry-specification-v1.55.0/trace/sdk_exporters/stdout.md#L16)
- [ ] Default pairing with Simple SpanProcessor — [L29-L34](references/opentelemetry-specification-v1.55.0/trace/sdk_exporters/stdout.md#L29)

## OTLP Protocol

> Ref: [protocol/otlp.md](references/opentelemetry-specification-v1.55.0/protocol/otlp.md)

### Encoding

- [ ] Binary Protobuf encoding (Proto3) — [L44-L52](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L44)
- [ ] JSON Protobuf encoding: traceId/spanId as hex (not base64), enum as integers, lowerCamelCase keys — [L53-L78](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L53)
- [ ] Receivers must ignore unknown fields in JSON — [L73-L78](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L73)

### OTLP/HTTP

- [ ] Default endpoint: http://localhost:4318 — [L80-L86](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L80)
- [ ] Append signal-specific paths to base endpoint: /v1/traces, /v1/metrics, /v1/logs — [L87-L100](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L87)
- [ ] Per-signal endpoint used as-is (no path appending) — [L101-L106](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L101)
- [ ] HTTP POST requests for sending telemetry — [L107-L112](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L107)
- [ ] Support binary Protobuf (Content-Type: application/x-protobuf) — [L113-L118](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L113)
- [ ] Support JSON Protobuf (Content-Type: application/json) — optional but recommended — [L119-L124](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L119)
- [ ] Support gzip compression (Content-Encoding: gzip) — [L125-L130](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L125)
- [ ] Handle HTTP 200 OK (success) — [L131-L138](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L131)
- [ ] Handle partial success (HTTP 200 with partial_success field) — [L139-L160](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L139)
- [ ] Handle HTTP 400 Bad Request (non-retryable) — [L161-L168](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L161)
- [ ] Handle retryable status codes: 429, 502, 503, 504 — [L169-L185](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L169)
- [ ] Respect Retry-After header on 429/503 — [L186-L192](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L186)
- [ ] Exponential backoff with jitter for retries — [L193-L198](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L193)
- [ ] Must not modify URL beyond specified rules — [L199-L204](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L199)

### OTLP/gRPC

- [ ] Default endpoint: http://localhost:4317 — [L210-L216](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L210)
- [ ] Unary RPC calls with Export*ServiceRequest messages — [L217-L225](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L217)
- [ ] Support gzip compression — [L226-L230](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L226)
- [ ] Handle success: Export*ServiceResponse — [L231-L240](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L231)
- [ ] Handle partial success (partial_success field) — [L241-L260](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L241)
- [ ] Handle retryable gRPC status: UNAVAILABLE (with optional RetryInfo) — [L261-L278](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L261)
- [ ] Handle non-retryable gRPC status: INVALID_ARGUMENT — [L279-L288](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L279)
- [ ] Retryable gRPC codes: CANCELLED, DEADLINE_EXCEEDED, ABORTED, OUT_OF_RANGE, UNAVAILABLE, DATA_LOSS — [L289-L300](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L289)
- [ ] Non-retryable gRPC codes: UNKNOWN, INVALID_ARGUMENT, NOT_FOUND, ALREADY_EXISTS, PERMISSION_DENIED, UNAUTHENTICATED, FAILED_PRECONDITION, INTERNAL, UNIMPLEMENTED — [L301-L315](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L301)
- [ ] Exponential backoff with jitter for retries — [L316-L321](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L316)
- [ ] https scheme takes precedence over insecure setting — [L322-L326](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L322)
- [ ] Configurable concurrent request count — [L327-L332](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L327)
- [ ] `OTEL_EXPORTER_OTLP_INSECURE` — transport security (default: false) — [L333-L338](references/opentelemetry-specification-v1.55.0/protocol/otlp.md#L333)

## OTLP Exporter Configuration

> Ref: [protocol/exporter.md](references/opentelemetry-specification-v1.55.0/protocol/exporter.md)

### Common Configuration

- [ ] `OTEL_EXPORTER_OTLP_ENDPOINT` — base endpoint URL — [L36-L60](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L36)
- [ ] Per-signal endpoint overrides (`*_TRACES_ENDPOINT`, `*_METRICS_ENDPOINT`, `*_LOGS_ENDPOINT`) — [L61-L80](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L61)
- [ ] `OTEL_EXPORTER_OTLP_PROTOCOL` — grpc, http/protobuf, http/json (default: http/protobuf) — [L148-L170](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L148)
- [ ] Per-signal protocol overrides — [L171-L180](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L171)
- [ ] `OTEL_EXPORTER_OTLP_HEADERS` — key-value pairs as request headers — [L82-L108](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L82)
- [ ] Per-signal header overrides — [L109-L118](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L109)
- [ ] `OTEL_EXPORTER_OTLP_COMPRESSION` — gzip or none — [L120-L135](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L120)
- [ ] Per-signal compression overrides — [L136-L145](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L136)
- [ ] `OTEL_EXPORTER_OTLP_TIMEOUT` — per-batch timeout (default: 10s) — [L182-L200](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L182)
- [ ] Per-signal timeout overrides — [L201-L210](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L201)
- [ ] `OTEL_EXPORTER_OTLP_CERTIFICATE` — TLS certificate file — [L212-L230](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L212)
- [ ] Per-signal certificate overrides — [L231-L240](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L231)
- [ ] `OTEL_EXPORTER_OTLP_CLIENT_KEY` — mTLS client private key — [L242-L260](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L242)
- [ ] `OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE` — mTLS client certificate — [L261-L280](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L261)
- [ ] Signal-specific options take precedence over general options — [L30-L34](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L30)
- [ ] Emit User-Agent header (e.g., OTel-OTLP-Exporter-Elixir/VERSION) — [L281-L295](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L281)

## Metrics API

> Ref: [metrics/api.md](references/opentelemetry-specification-v1.55.0/metrics/api.md)

### MeterProvider

- [ ] Provide function to get/create a Meter — [L68-L74](references/opentelemetry-specification-v1.55.0/metrics/api.md#L68)
- [ ] Accept `name` parameter (required) — [L75-L86](references/opentelemetry-specification-v1.55.0/metrics/api.md#L75)
- [ ] Accept optional `version` parameter — [L87-L88](references/opentelemetry-specification-v1.55.0/metrics/api.md#L87)
- [ ] Accept optional `schema_url` parameter — [L89-L92](references/opentelemetry-specification-v1.55.0/metrics/api.md#L89)
- [ ] Accept optional `attributes` parameter (instrumentation scope) — [L93-L98](references/opentelemetry-specification-v1.55.0/metrics/api.md#L93)
- [ ] Return working Meter even for invalid names — [L99-L106](references/opentelemetry-specification-v1.55.0/metrics/api.md#L99)
- [ ] Provide global default MeterProvider mechanism — [L58-L66](references/opentelemetry-specification-v1.55.0/metrics/api.md#L58)
- [ ] Thread-safe for concurrent use — [L107-L109](references/opentelemetry-specification-v1.55.0/metrics/api.md#L107)

### Meter

- [ ] Provide functions to create all instrument types — [L118-L127](references/opentelemetry-specification-v1.55.0/metrics/api.md#L118)
- [ ] Thread-safe for concurrent use — [L128-L130](references/opentelemetry-specification-v1.55.0/metrics/api.md#L128)

### Instrument General

- [ ] Instrument identity: name, kind, unit, description — [L136-L145](references/opentelemetry-specification-v1.55.0/metrics/api.md#L136)
- [ ] Name: starts with alpha, max 255 chars, case-insensitive — [L146-L158](references/opentelemetry-specification-v1.55.0/metrics/api.md#L146)
- [ ] Name: allows alphanumeric, underscore, period, hyphen, forward slash — [L159-L165](references/opentelemetry-specification-v1.55.0/metrics/api.md#L159)
- [ ] Unit: optional, case-sensitive, max 63 ASCII chars — [L166-L175](references/opentelemetry-specification-v1.55.0/metrics/api.md#L166)
- [ ] Description: optional, supports BMP Unicode, at least 1023 chars — [L176-L185](references/opentelemetry-specification-v1.55.0/metrics/api.md#L176)

### Counter

- [ ] Create with name, optional unit, description, advisory params — [L198-L212](references/opentelemetry-specification-v1.55.0/metrics/api.md#L198)
- [ ] Add: accept non-negative increment value and optional attributes — [L213-L230](references/opentelemetry-specification-v1.55.0/metrics/api.md#L213)
- [ ] Enabled API returning boolean — [L231-L238](references/opentelemetry-specification-v1.55.0/metrics/api.md#L231)

### UpDownCounter

- [ ] Create with name, optional unit, description, advisory params — [L240-L254](references/opentelemetry-specification-v1.55.0/metrics/api.md#L240)
- [ ] Add: accept positive or negative value and optional attributes — [L255-L272](references/opentelemetry-specification-v1.55.0/metrics/api.md#L255)
- [ ] Enabled API returning boolean — [L273-L280](references/opentelemetry-specification-v1.55.0/metrics/api.md#L273)

### Histogram

- [ ] Create with name, optional unit, description, advisory params — [L282-L296](references/opentelemetry-specification-v1.55.0/metrics/api.md#L282)
- [ ] Record: accept non-negative value and optional attributes — [L297-L314](references/opentelemetry-specification-v1.55.0/metrics/api.md#L297)
- [ ] Enabled API returning boolean — [L315-L322](references/opentelemetry-specification-v1.55.0/metrics/api.md#L315)

### Gauge

- [ ] Create with name, optional unit, description, advisory params — [L324-L338](references/opentelemetry-specification-v1.55.0/metrics/api.md#L324)
- [ ] Record: accept value (absolute current) and optional attributes — [L339-L356](references/opentelemetry-specification-v1.55.0/metrics/api.md#L339)
- [ ] Enabled API returning boolean — [L357-L364](references/opentelemetry-specification-v1.55.0/metrics/api.md#L357)

### Observable Counter

- [ ] Create with name, optional unit, description, advisory params, callbacks — [L376-L393](references/opentelemetry-specification-v1.55.0/metrics/api.md#L376)
- [ ] Callback reports absolute monotonically increasing value — [L394-L400](references/opentelemetry-specification-v1.55.0/metrics/api.md#L394)
- [ ] Support callback registration/unregistration after creation — [L401-L408](references/opentelemetry-specification-v1.55.0/metrics/api.md#L401)

### Observable UpDownCounter

- [ ] Create with name, optional unit, description, advisory params, callbacks — [L410-L427](references/opentelemetry-specification-v1.55.0/metrics/api.md#L410)
- [ ] Callback reports absolute additive value — [L428-L434](references/opentelemetry-specification-v1.55.0/metrics/api.md#L428)
- [ ] Support callback registration/unregistration after creation — [L435-L442](references/opentelemetry-specification-v1.55.0/metrics/api.md#L435)

### Observable Gauge

- [ ] Create with name, optional unit, description, advisory params, callbacks — [L444-L461](references/opentelemetry-specification-v1.55.0/metrics/api.md#L444)
- [ ] Callback reports non-additive value — [L462-L468](references/opentelemetry-specification-v1.55.0/metrics/api.md#L462)
- [ ] Support callback registration/unregistration after creation — [L469-L476](references/opentelemetry-specification-v1.55.0/metrics/api.md#L469)

### Callback Requirements

- [ ] Callbacks evaluated exactly once per collection per instrument — [L480-L488](references/opentelemetry-specification-v1.55.0/metrics/api.md#L480)
- [ ] Observations from single callback treated as same instant — [L489-L494](references/opentelemetry-specification-v1.55.0/metrics/api.md#L489)
- [ ] Should be reentrant safe — [L495-L498](references/opentelemetry-specification-v1.55.0/metrics/api.md#L495)
- [ ] Should not make duplicate observations (same attributes) — [L499-L504](references/opentelemetry-specification-v1.55.0/metrics/api.md#L499)

## Metrics SDK

> Ref: [metrics/sdk.md](references/opentelemetry-specification-v1.55.0/metrics/sdk.md)

### MeterProvider

- [ ] Specify Resource at creation — [L28-L32](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L28)
- [ ] Configure MetricExporters, MetricReaders, Views — [L33-L42](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L33)
- [ ] Support multiple MetricReader registration (independent operation) — [L43-L48](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L43)
- [ ] Shutdown: call once, invoke Shutdown on all MetricReaders and MetricExporters — [L80-L108](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L80)
- [ ] Shutdown: return success/failure/timeout; subsequent meter requests return no-op — [L100-L104](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L100)
- [ ] ForceFlush: invoke on all registered MetricReaders — [L110-L130](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L110)
- [ ] Thread-safe for meter creation, ForceFlush, Shutdown — [L131-L136](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L131)
- [ ] Return working Meter for invalid names (log the issue) — [L49-L56](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L49)

### Meter

- [ ] Validate instrument names on creation — [L140-L148](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L140)
- [ ] Emit error for invalid instrument names — [L149-L153](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L149)
- [ ] Handle duplicate instrument registration (warn, aggregate identical) — [L154-L168](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L154)
- [ ] Case-insensitive name handling: return first-seen casing — [L169-L175](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L169)
- [ ] Null/missing unit and description treated as empty string — [L176-L180](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L176)
- [ ] Advisory parameters: View config takes precedence — [L181-L186](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L181)
- [ ] Instrument Enabled: false when MeterConfig disabled or all Views use Drop — [L187-L195](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L187)

### Views

- [ ] Instrument selection criteria: name (exact/wildcard), type, unit, meter_name, meter_version, meter_schema_url — [L200-L225](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L200)
- [ ] Single asterisk matches all instruments — [L226-L230](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L226)
- [ ] Selection criteria are additive (AND logic) — [L231-L235](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L231)
- [ ] Stream configuration: name override, description override — [L236-L250](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L236)
- [ ] Stream configuration: attribute key allow-list/exclude-list — [L251-L265](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L251)
- [ ] Stream configuration: aggregation specification — [L266-L275](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L266)
- [ ] Stream configuration: exemplar_reservoir, aggregation_cardinality_limit — [L276-L285](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L276)
- [ ] No Views registered: apply default aggregation per instrument kind — [L286-L292](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L286)
- [ ] Registered Views: independently apply each matching View — [L293-L300](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L293)
- [ ] No matching View: enable with default aggregation — [L301-L306](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L301)
- [ ] Views not merged; warn on conflicting metric identities — [L307-L315](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L307)

### Aggregation

- [ ] Drop aggregation: ignore all measurements — [L320-L328](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L320)
- [ ] Default aggregation: select per instrument kind — [L329-L345](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L329)
- [ ] Sum aggregation: arithmetic sum of measurements — [L346-L360](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L346)
- [ ] Last Value aggregation: last measurement with timestamp — [L361-L375](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L361)
- [ ] Explicit Bucket Histogram: count, sum, optional min/max — [L376-L400](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L376)
- [ ] Explicit Bucket Histogram default boundaries: [0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000] — [L401-L405](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L401)
- [ ] Explicit Bucket Histogram RecordMinMax (default: true) — [L406-L410](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L406)
- [ ] Buckets: exclusive of lower bound, inclusive of upper bound — [L411-L415](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L411)

### Default Aggregation Mapping

- [ ] Counter / Observable Counter -> Sum (monotonic) — [L335-L337](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L335)
- [ ] UpDownCounter / Observable UpDownCounter -> Sum (non-monotonic) — [L338-L340](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L338)
- [ ] Gauge / Observable Gauge -> Last Value — [L341-L343](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L341)
- [ ] Histogram -> Explicit Bucket Histogram — [L344-L345](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L344)

### Temporal Aggregation

- [ ] Cumulative temporality: consistent start timestamp across all collection intervals — [L420-L430](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L420)
- [ ] Cumulative: data points persist regardless of new measurements — [L431-L435](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L431)
- [ ] Delta temporality: start timestamp advances between collections — [L436-L446](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L436)
- [ ] Delta: only data points with measurements since previous collection — [L447-L451](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L447)

### Cardinality Limits

- [ ] View-specific limit takes precedence — [L455-L462](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L455)
- [ ] MetricReader default limit applies second — [L463-L468](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L463)
- [ ] Default cardinality limit: 2000 — [L469-L473](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L469)
- [ ] Enforce after attribute filtering — [L474-L478](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L474)
- [ ] Overflow aggregator with attribute `otel.metric.overflow=true` — [L479-L488](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L479)
- [ ] Every measurement reflected exactly once (no double-counting/dropping) — [L489-L494](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L489)

### Exemplars

- [ ] Exemplar sampling on by default — [L500-L506](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L500)
- [ ] ExemplarFilter: AlwaysOn, AlwaysOff, TraceBased (default) — [L507-L520](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L507)
- [ ] Configurable ExemplarReservoir per View — [L521-L528](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L521)
- [ ] ExemplarReservoir: offer (value, attributes, context, timestamp) — [L529-L540](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L529)
- [ ] ExemplarReservoir: collect (respect aggregation temporality) — [L541-L552](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L541)
- [ ] Return attributes not already in metric data point — [L553-L560](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L553)
- [ ] SimpleFixedSizeExemplarReservoir: uniform sampling (default for most) — [L561-L572](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L561)
- [ ] AlignedHistogramBucketExemplarReservoir: one per bucket (default for histograms) — [L573-L584](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L573)
- [ ] Thread-safe ExemplarReservoir methods — [L585-L590](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L585)

### MetricReader

- [ ] Configure: exporter, default aggregation, output temporality, cardinality limit — [L595-L615](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L595)
- [ ] Optional: MetricProducers, MetricFilter — [L616-L625](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L616)
- [ ] Collect: gather metrics from SDK and MetricProducers — [L626-L645](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L626)
- [ ] Collect: trigger asynchronous instrument callbacks — [L646-L652](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L646)
- [ ] Collect: return success/failure/timeout — [L653-L658](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L653)
- [ ] Shutdown: call once; subsequent Collect not allowed — [L659-L672](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L659)
- [ ] Support multiple MetricReaders on same MeterProvider (independent) — [L673-L680](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L673)
- [ ] MetricReader must not be registered on multiple MeterProviders — [L681-L685](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L681)

### Periodic Exporting MetricReader

- [ ] exportIntervalMillis configuration (default: 60000) — [L690-L695](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L690)
- [ ] exportTimeoutMillis configuration (default: 30000) — [L696-L700](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L696)
- [ ] Collect metrics on configurable interval — [L701-L706](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L701)
- [ ] Synchronize exporter calls (no concurrent invocation) — [L707-L710](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L707)
- [ ] ForceFlush: collect and export immediately — [L711-L718](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L711)

### MetricExporter (Push)

- [ ] Export: accept metrics, return Success or Failure — [L725-L760](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L725)
- [ ] Export must not be called concurrently for same instance — [L731-L732](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L731)
- [ ] Export must not block indefinitely — [L742-L744](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L742)
- [ ] Shutdown: call once; subsequent Export returns Failure — [L790-L810](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L790)
- [ ] Shutdown must not block indefinitely — [L804-L806](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L804)
- [ ] ForceFlush: hint to complete prior exports — [L770-L788](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L770)
- [ ] ForceFlush and Shutdown must be thread-safe — [L811-L817](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L811)

## Metrics Exporters

### Console (stdout)

> Ref: [metrics/sdk_exporters/stdout.md](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md)

- [ ] Output metrics to stdout/console — [L9-L10](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md#L9)
- [ ] Output format is implementation-defined — [L12-L13](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md#L12)
- [ ] Document as debugging/learning tool, not for production — [L16-L18](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md#L16)
- [ ] Default temporality: Cumulative for all instrument kinds — [L20-L24](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md#L20)
- [ ] Pair with Periodic Exporting MetricReader (default interval: 10000ms) — [L26-L32](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md#L26)

## Logs API

> Ref: [logs/api.md](references/opentelemetry-specification-v1.55.0/logs/api.md)

### LoggerProvider

- [ ] Provide function to get a Logger — [L53-L59](references/opentelemetry-specification-v1.55.0/logs/api.md#L53)
- [ ] Accept `name` parameter (required) — [L60-L71](references/opentelemetry-specification-v1.55.0/logs/api.md#L60)
- [ ] Accept optional `version`, `schema_url`, `attributes` parameters — [L72-L84](references/opentelemetry-specification-v1.55.0/logs/api.md#L72)
- [ ] Provide global default LoggerProvider mechanism — [L43-L51](references/opentelemetry-specification-v1.55.0/logs/api.md#L43)
- [ ] Thread-safe for concurrent use — [L85-L87](references/opentelemetry-specification-v1.55.0/logs/api.md#L85)

### Logger

- [ ] Provide function to emit LogRecord — [L96-L102](references/opentelemetry-specification-v1.55.0/logs/api.md#L96)
- [ ] Accept optional: Timestamp, Observed Timestamp, Context, Severity Number, Severity Text, Body, Attributes, Event Name — [L103-L136](references/opentelemetry-specification-v1.55.0/logs/api.md#L103)
- [ ] Provide Enabled API returning boolean — [L138-L156](references/opentelemetry-specification-v1.55.0/logs/api.md#L138)
- [ ] Enabled accepts optional: Context, Severity Number, Event Name — [L148-L156](references/opentelemetry-specification-v1.55.0/logs/api.md#L148)
- [ ] Thread-safe for concurrent use — [L157-L159](references/opentelemetry-specification-v1.55.0/logs/api.md#L157)

## Logs SDK

> Ref: [logs/sdk.md](references/opentelemetry-specification-v1.55.0/logs/sdk.md)

### LoggerProvider

- [ ] Specify Resource at creation — [L39-L43](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L39)
- [ ] Configure LogRecordProcessors — [L44-L50](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L44)
- [ ] Updated configuration applies to all existing Loggers — [L51-L56](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L51)
- [ ] Shutdown: call once; subsequent Logger retrieval not allowed — [L82-L110](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L82)
- [ ] Shutdown: invoke Shutdown on all registered LogRecordProcessors — [L92-L96](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L92)
- [ ] ForceFlush: invoke ForceFlush on all registered LogRecordProcessors — [L112-L132](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L112)
- [ ] Thread-safe for Logger creation, ForceFlush, Shutdown — [L133-L138](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L133)

### Logger

- [ ] Set ObservedTimestamp to current time if unspecified — [L145-L152](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L145)
- [ ] Apply exception semantic conventions to exception attributes — [L153-L162](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L153)
- [ ] User-provided attributes must not be overwritten by exception-derived attributes — [L163-L168](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L163)
- [ ] Thread-safe for all methods — [L649-L661](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L649)

### LogRecord Limits

- [ ] Configurable attribute count limit — [L175-L182](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L175)
- [ ] Configurable attribute value length limit — [L183-L190](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L183)
- [ ] `OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT` env var — [L163](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L163)
- [ ] `OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT` env var (default: 128) — [L164](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L164)
- [ ] Log message when attributes discarded (at most once per LogRecord) — [L191-L197](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L191)

### LogRecordProcessor

- [ ] OnEmit: called synchronously; must not block/throw — [L390-L407](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L390)
- [ ] LogRecord mutations visible to next registered processors — [L408-L409](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L408)
- [ ] Shutdown: call once; subsequent OnEmit not allowed — [L457-L464](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L457)
- [ ] ForceFlush: complete or abort within timeout — [L476-L503](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L476)
- [ ] Thread-safe for all methods — [L649-L661](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L649)

### Simple LogRecordProcessor

- [ ] Pass finished LogRecords to LogRecordExporter immediately — [L514-L519](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L514)
- [ ] Synchronize Export calls (no concurrent invocation) — [L521-L522](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L521)

### Batch LogRecordProcessor

- [ ] Create batches of LogRecords for export — [L528-L535](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L528)
- [ ] Synchronize Export calls (no concurrent invocation) — [L534-L535](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L534)
- [ ] maxQueueSize configuration (default: 2048) — [L540-L541](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L540)
- [ ] scheduledDelayMillis configuration (default: 1000) — [L542-L543](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L542)
- [ ] exportTimeoutMillis configuration (default: 30000) — [L544-L545](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L544)
- [ ] maxExportBatchSize configuration (default: 512) — [L546-L547](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L546)
- [ ] `OTEL_BLRP_SCHEDULE_DELAY` env var (default: 1000) — [L167](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L167)
- [ ] `OTEL_BLRP_EXPORT_TIMEOUT` env var (default: 30000) — [L168](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L168)
- [ ] `OTEL_BLRP_MAX_QUEUE_SIZE` env var (default: 2048) — [L169](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L169)
- [ ] `OTEL_BLRP_MAX_EXPORT_BATCH_SIZE` env var (default: 512) — [L170](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L170)

### LogRecordExporter

- [ ] Export: accept batch of LogRecords, return Success or Failure — [L566-L612](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L566)
- [ ] Export must not be called concurrently for same instance — [L572-L573](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L572)
- [ ] Export must not block indefinitely — [L582-L583](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L582)
- [ ] Shutdown: call once; subsequent Export returns Failure — [L632-L639](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L632)
- [ ] ForceFlush and Shutdown must be thread-safe — [L659-L660](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L659)

## Logs Exporters

### Console (stdout)

> Ref: [logs/sdk_exporters/stdout.md](references/opentelemetry-specification-v1.55.0/logs/sdk_exporters/stdout.md)

- [ ] Output LogRecords to stdout/console — [L9-L10](references/opentelemetry-specification-v1.55.0/logs/sdk_exporters/stdout.md#L9)
- [ ] Output format is implementation-defined — [L12-L13](references/opentelemetry-specification-v1.55.0/logs/sdk_exporters/stdout.md#L12)
- [ ] Document as debugging/learning tool, not for production — [L16-L18](references/opentelemetry-specification-v1.55.0/logs/sdk_exporters/stdout.md#L16)
- [ ] Default pairing with Simple LogRecordProcessor — [L29-L34](references/opentelemetry-specification-v1.55.0/logs/sdk_exporters/stdout.md#L29)

## Environment Variables

> Ref: [configuration/sdk-environment-variables.md](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md)

### General SDK Configuration

- [ ] `OTEL_SDK_DISABLED` — disable SDK for all signals (default: false) — [L113](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L113)
- [ ] `OTEL_RESOURCE_ATTRIBUTES` — key-value pairs for resource attributes — [L115](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L115)
- [ ] `OTEL_SERVICE_NAME` — set service.name resource attribute — [L116](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L116)
- [ ] `OTEL_LOG_LEVEL` — SDK internal logger level (default: info) — [L117](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L117)
- [ ] `OTEL_PROPAGATORS` — comma-separated propagator list (default: tracecontext,baggage) — [L118](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L118)
- [ ] `OTEL_TRACES_SAMPLER` — sampler for traces (default: parentbased_always_on) — [L119](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L119)
- [ ] `OTEL_TRACES_SAMPLER_ARG` — sampler argument — [L120](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L120)
- [ ] `OTEL_TRACES_EXPORTER` — trace exporter (default: otlp) — [L243](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L243)
- [ ] `OTEL_METRICS_EXPORTER` — metrics exporter (default: otlp) — [L244](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L244)
- [ ] `OTEL_LOGS_EXPORTER` — logs exporter (default: otlp) — [L245](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L245)
- [ ] `OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT` — global attribute value length limit — [L181](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L181)
- [ ] `OTEL_ATTRIBUTE_COUNT_LIMIT` — global attribute count limit (default: 128) — [L182](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L182)
