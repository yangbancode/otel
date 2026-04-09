# OpenTelemetry Specification v1.55.0 Compliance

Stable specification items only. Organized by specification structure. Check items as they are implemented.


## Common & Foundation

### Attributes

> Ref: [common/README.md](references/opentelemetry-specification-v1.55.0/common/README.md)

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

### Context API

> Ref: [context/README.md](references/opentelemetry-specification-v1.55.0/context/README.md)

- [ ] Context is immutable; write operations return new Context — [L37-L39](references/opentelemetry-specification-v1.55.0/context/README.md#L37)
- [ ] Create a key: accept key name, return opaque key object — [L63-L67](references/opentelemetry-specification-v1.55.0/context/README.md#L63)
- [ ] Get value: accept Context and key, return associated value — [L74-L79](references/opentelemetry-specification-v1.55.0/context/README.md#L74)
- [ ] Set value: accept Context, key, and value, return new Context — [L86-L92](references/opentelemetry-specification-v1.55.0/context/README.md#L86)
- [ ] Get current Context (for implicit propagation) — [L103](references/opentelemetry-specification-v1.55.0/context/README.md#L103)
- [ ] Attach Context: accept Context, return token for detachment — [L109-L114](references/opentelemetry-specification-v1.55.0/context/README.md#L109)
- [ ] Detach Context: accept token, restore previous Context — [L119-L136](references/opentelemetry-specification-v1.55.0/context/README.md#L119)

### Propagators — TextMapPropagator

> Ref: [context/api-propagators.md](references/opentelemetry-specification-v1.55.0/context/api-propagators.md)

- [ ] Inject: accept Context and carrier, set propagation fields — [L87-L96](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L87)
- [ ] Extract: accept Context and carrier, return new Context with extracted values — [L98-L112](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L98)
- [ ] Extract must not throw on unparseable values — [L101-L103](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L101)
- [ ] Fields: return list of propagation keys used during injection — [L133-L149](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L133)
- [ ] TextMapGetter: Keys, Get (first value), GetAll methods — [L207-L249](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L207)
- [ ] TextMapSetter: Set method, preserve casing for case-insensitive protocols — [L165-L183](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L165)

### Composite Propagator

> Ref: [context/api-propagators.md](references/opentelemetry-specification-v1.55.0/context/api-propagators.md)

- [ ] Combine multiple propagators into one — [L259-L266](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L259)
- [ ] Invoke component propagators in registration order — [L266](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L266)

### Global Propagators

> Ref: [context/api-propagators.md](references/opentelemetry-specification-v1.55.0/context/api-propagators.md)

- [ ] Provide get/set for global propagator — [L334-L348](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L334)
- [ ] Default to no-op propagator unless explicitly configured — [L322-L326](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L322)

### W3C TraceContext Propagator

> Ref: [context/api-propagators.md](references/opentelemetry-specification-v1.55.0/context/api-propagators.md), [trace/tracestate-handling.md](references/opentelemetry-specification-v1.55.0/trace/tracestate-handling.md)

- [ ] Parse and validate `traceparent` header per W3C Trace Context Level 2 — [L383](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L383)
- [ ] Parse and validate `tracestate` header — [L383](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L383)
- [ ] Inject valid `traceparent` header — [L383](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L383)
- [ ] Inject valid `tracestate` header (unless empty) — [L383](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L383)
- [ ] Propagate TraceId (16 bytes), SpanId (8 bytes), TraceFlags, TraceState — [L385-L390](references/opentelemetry-specification-v1.55.0/context/api-propagators.md#L385)

### W3C Baggage Propagator

> Ref: [baggage/api.md](references/opentelemetry-specification-v1.55.0/baggage/api.md)

- [ ] Implement TextMapPropagator for W3C Baggage specification — [L184-L186](references/opentelemetry-specification-v1.55.0/baggage/api.md#L184)
- [ ] On conflict, new pair takes precedence — [L206-L208](references/opentelemetry-specification-v1.55.0/baggage/api.md#L206)

### Baggage API

> Ref: [baggage/api.md](references/opentelemetry-specification-v1.55.0/baggage/api.md)

- [ ] Get value by name (return value or null) — [L89-L97](references/opentelemetry-specification-v1.55.0/baggage/api.md#L89)
- [ ] Get all name/value pairs (order not significant) — [L99-L104](references/opentelemetry-specification-v1.55.0/baggage/api.md#L99)
- [ ] Set value: accept name, value (strings), optional metadata — [L107-L124](references/opentelemetry-specification-v1.55.0/baggage/api.md#L107)
- [ ] Remove value by name (return new Baggage without entry) — [L128-L136](references/opentelemetry-specification-v1.55.0/baggage/api.md#L128)
- [ ] Each name associates with exactly one value — [L38-L41](references/opentelemetry-specification-v1.55.0/baggage/api.md#L38)
- [ ] Names and values are valid UTF-8 strings; names must be non-empty — [L43-L55](references/opentelemetry-specification-v1.55.0/baggage/api.md#L43)
- [ ] Case-sensitive treatment of names and values — [L57-L58](references/opentelemetry-specification-v1.55.0/baggage/api.md#L57)
- [ ] Baggage container is immutable — [L84-L85](references/opentelemetry-specification-v1.55.0/baggage/api.md#L84)
- [ ] Metadata: opaque string wrapper with no semantic meaning — [L122-L124](references/opentelemetry-specification-v1.55.0/baggage/api.md#L122)

### Baggage — Context Interaction

> Ref: [baggage/api.md](references/opentelemetry-specification-v1.55.0/baggage/api.md)

- [ ] Extract Baggage from Context — [L146](references/opentelemetry-specification-v1.55.0/baggage/api.md#L146)
- [ ] Insert Baggage into Context — [L147](references/opentelemetry-specification-v1.55.0/baggage/api.md#L147)
- [ ] Retrieve and set active Baggage (for implicit propagation) — [L153-L161](references/opentelemetry-specification-v1.55.0/baggage/api.md#L153)
- [ ] Remove all Baggage entries from a Context — [L169-L176](references/opentelemetry-specification-v1.55.0/baggage/api.md#L169)

### Baggage — Propagation

> Ref: [baggage/api.md](references/opentelemetry-specification-v1.55.0/baggage/api.md)

- [ ] W3C Baggage TextMapPropagator implementation — [L184-L186](references/opentelemetry-specification-v1.55.0/baggage/api.md#L184)
- [ ] On conflict, new pair takes precedence — [L206-L208](references/opentelemetry-specification-v1.55.0/baggage/api.md#L206)

### Baggage — Functional Without SDK

> Ref: [baggage/api.md](references/opentelemetry-specification-v1.55.0/baggage/api.md)

- [ ] API must be fully functional without an installed SDK — [L79-L82](references/opentelemetry-specification-v1.55.0/baggage/api.md#L79)

### Resource

> Ref: [resource/sdk.md](references/opentelemetry-specification-v1.55.0/resource/sdk.md)

- [ ] Create Resource from attributes — [L56-L60](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L56)
- [ ] Accept optional schema_url — [L65-L67](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L65)
- [ ] Merge two Resources (updating resource values take precedence) — [L69-L80](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L69)
- [ ] Schema URL merge rules (empty, matching, conflicting) — [L82-L92](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L82)
- [ ] Support empty Resource creation — [L99-L102](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L99)
- [ ] Associate Resource with TracerProvider at creation (immutable after) — [L26-L29](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L26)
- [ ] Associate Resource with MeterProvider at creation (immutable after) — [L31-L35](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L31)
- [ ] Associate Resource with LoggerProvider at creation (immutable after) — [L59](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L59)
- [ ] Provide default Resource with SDK attributes (telemetry.sdk.*) — [L39-L42](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L39)
- [ ] Extract `OTEL_RESOURCE_ATTRIBUTES` env var and merge (user-provided takes priority) — [L178-L189](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L178)
- [ ] Extract `OTEL_SERVICE_NAME` env var — [L116](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L116)
- [ ] Resource detection must not fail on detection errors — [L118-L124](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L118)
- [ ] Resource attributes are immutable after creation — [L197](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L197)
- [ ] Provide read-only attribute retrieval — [L200-L202](references/opentelemetry-specification-v1.55.0/resource/sdk.md#L200)

## Traces

### Trace API — TracerProvider

> Ref: [trace/api.md](references/opentelemetry-specification-v1.55.0/trace/api.md)

- [ ] Provide function to get a Tracer — [L109-L111](references/opentelemetry-specification-v1.55.0/trace/api.md#L109)
- [ ] Accept `name` parameter (required) — [L117-L134](references/opentelemetry-specification-v1.55.0/trace/api.md#L117)
- [ ] Accept optional `version` parameter — [L135-L136](references/opentelemetry-specification-v1.55.0/trace/api.md#L135)
- [ ] Accept optional `schema_url` parameter — [L137-L138](references/opentelemetry-specification-v1.55.0/trace/api.md#L137)
- [ ] Accept optional `attributes` parameter (instrumentation scope) — [L139-L140](references/opentelemetry-specification-v1.55.0/trace/api.md#L139)
- [ ] Return working Tracer even for invalid names (no null/exception) — [L126-L128](references/opentelemetry-specification-v1.55.0/trace/api.md#L126)
- [ ] Provide global default TracerProvider mechanism — [L96-L97](references/opentelemetry-specification-v1.55.0/trace/api.md#L96)
- [ ] Configuration changes apply to already-returned Tracers — [L146-L149](references/opentelemetry-specification-v1.55.0/trace/api.md#L146)
- [ ] Thread-safe for concurrent use — [L842-L843](references/opentelemetry-specification-v1.55.0/trace/api.md#L842)

### Trace API — Tracer

> Ref: [trace/api.md](references/opentelemetry-specification-v1.55.0/trace/api.md)

- [ ] Provide function to create new Spans — [L193-L195](references/opentelemetry-specification-v1.55.0/trace/api.md#L193)
- [ ] Provide Enabled API returning boolean — [L201-L214](references/opentelemetry-specification-v1.55.0/trace/api.md#L201)
- [ ] Thread-safe for concurrent use — [L845-L846](references/opentelemetry-specification-v1.55.0/trace/api.md#L845)

### Trace API — SpanContext

> Ref: [trace/api.md](references/opentelemetry-specification-v1.55.0/trace/api.md)

- [ ] TraceId: 16-byte array, at least one non-zero byte — [L231-L232](references/opentelemetry-specification-v1.55.0/trace/api.md#L231)
- [ ] SpanId: 8-byte array, at least one non-zero byte — [L234-L235](references/opentelemetry-specification-v1.55.0/trace/api.md#L234)
- [ ] TraceFlags: Sampled flag, Random flag — [L237-L242](references/opentelemetry-specification-v1.55.0/trace/api.md#L237)
- [ ] TraceState: immutable key-value list per W3C spec — [L244-L247](references/opentelemetry-specification-v1.55.0/trace/api.md#L244)
- [ ] IsRemote: boolean indicating remote origin — [L249-L250](references/opentelemetry-specification-v1.55.0/trace/api.md#L249)
- [ ] Provide TraceId/SpanId as hex (lowercase) and binary — [L258-L264](references/opentelemetry-specification-v1.55.0/trace/api.md#L258)
- [ ] IsValid: true when TraceId and SpanId are both non-zero — [L270-L271](references/opentelemetry-specification-v1.55.0/trace/api.md#L270)
- [ ] IsRemote: true when propagated from remote parent — [L275-L278](references/opentelemetry-specification-v1.55.0/trace/api.md#L275)

### Trace API — TraceState

> Ref: [trace/api.md](references/opentelemetry-specification-v1.55.0/trace/api.md), [trace/tracestate-handling.md](references/opentelemetry-specification-v1.55.0/trace/tracestate-handling.md)

- [ ] Get value for key — [L286](references/opentelemetry-specification-v1.55.0/trace/api.md#L286)
- [ ] Add new key/value pair (returns new TraceState) — [L287](references/opentelemetry-specification-v1.55.0/trace/api.md#L287)
- [ ] Update existing key/value pair (returns new TraceState) — [L288](references/opentelemetry-specification-v1.55.0/trace/api.md#L288)
- [ ] Delete key/value pair (returns new TraceState) — [L289](references/opentelemetry-specification-v1.55.0/trace/api.md#L289)
- [ ] Validate input parameters; never return invalid data — [L293-L296](references/opentelemetry-specification-v1.55.0/trace/api.md#L293)
- [ ] All mutations return new TraceState (immutable) — [L292](references/opentelemetry-specification-v1.55.0/trace/api.md#L292)

### Trace API — Span Creation

> Ref: [trace/api.md](references/opentelemetry-specification-v1.55.0/trace/api.md)

- [ ] Spans created only via Tracer (no other API) — [L380](references/opentelemetry-specification-v1.55.0/trace/api.md#L380)
- [ ] Accept span name (required) — [L389](references/opentelemetry-specification-v1.55.0/trace/api.md#L389)
- [ ] Accept parent Context or root span indication — [L390-L393](references/opentelemetry-specification-v1.55.0/trace/api.md#L390)
- [ ] Accept SpanKind (default: Internal) — [L397](references/opentelemetry-specification-v1.55.0/trace/api.md#L397)
- [ ] Accept initial Attributes — [L398-L400](references/opentelemetry-specification-v1.55.0/trace/api.md#L398)
- [ ] Accept Links (ordered sequence) — [L407](references/opentelemetry-specification-v1.55.0/trace/api.md#L407)
- [ ] Accept start timestamp (default: current time) — [L408-L410](references/opentelemetry-specification-v1.55.0/trace/api.md#L408)
- [ ] Root span option generates new TraceId — [L416-L417](references/opentelemetry-specification-v1.55.0/trace/api.md#L416)
- [ ] Child span TraceId matches parent — [L418](references/opentelemetry-specification-v1.55.0/trace/api.md#L418)
- [ ] Child inherits parent TraceState by default — [L419](references/opentelemetry-specification-v1.55.0/trace/api.md#L419)
- [ ] Preserve order of Links — [L830](references/opentelemetry-specification-v1.55.0/trace/api.md#L830)

### Trace API — SpanKind

> Ref: [trace/api.md](references/opentelemetry-specification-v1.55.0/trace/api.md)

- [ ] SERVER — [L775-L776](references/opentelemetry-specification-v1.55.0/trace/api.md#L775)
- [ ] CLIENT — [L777-L780](references/opentelemetry-specification-v1.55.0/trace/api.md#L777)
- [ ] PRODUCER — [L781-L786](references/opentelemetry-specification-v1.55.0/trace/api.md#L781)
- [ ] CONSUMER — [L787-L788](references/opentelemetry-specification-v1.55.0/trace/api.md#L787)
- [ ] INTERNAL (default) — [L789-L791](references/opentelemetry-specification-v1.55.0/trace/api.md#L789)

### Trace API — Span Operations

> Ref: [trace/api.md](references/opentelemetry-specification-v1.55.0/trace/api.md)

- [ ] GetContext: return SpanContext (same for entire lifetime) — [L457-L461](references/opentelemetry-specification-v1.55.0/trace/api.md#L457)
- [ ] IsRecording: return boolean; false after End — [L465-L478](references/opentelemetry-specification-v1.55.0/trace/api.md#L465)
- [ ] SetAttribute: set single attribute (overwrite on same key) — [L497-L511](references/opentelemetry-specification-v1.55.0/trace/api.md#L497)
- [ ] SetAttributes: set multiple attributes at once (optional) — [L505-L508](references/opentelemetry-specification-v1.55.0/trace/api.md#L505)
- [ ] AddEvent: record event with name, timestamp, and attributes — [L521-L542](references/opentelemetry-specification-v1.55.0/trace/api.md#L521)
- [ ] Events preserve recording order — [L544](references/opentelemetry-specification-v1.55.0/trace/api.md#L544)
- [ ] AddLink: add Link after span creation (SpanContext + attributes) — [L562](references/opentelemetry-specification-v1.55.0/trace/api.md#L562)
- [ ] SetStatus: accept StatusCode (Unset, Ok, Error) and optional description — [L567-L600](references/opentelemetry-specification-v1.55.0/trace/api.md#L567)
- [ ] Status Ok is final (ignore subsequent changes) — [L619-L620](references/opentelemetry-specification-v1.55.0/trace/api.md#L619)
- [ ] Setting Unset is ignored — [L604](references/opentelemetry-specification-v1.55.0/trace/api.md#L604)
- [ ] Status order: Ok > Error > Unset — [L590](references/opentelemetry-specification-v1.55.0/trace/api.md#L590)
- [ ] UpdateName: update span name — [L628-L645](references/opentelemetry-specification-v1.55.0/trace/api.md#L628)
- [ ] End: signal span completion; ignore subsequent calls — [L647-L655](references/opentelemetry-specification-v1.55.0/trace/api.md#L647)
- [ ] End accepts optional explicit end timestamp — [L672](references/opentelemetry-specification-v1.55.0/trace/api.md#L672)
- [ ] End must not block calling thread (no blocking I/O) — [L675-L677](references/opentelemetry-specification-v1.55.0/trace/api.md#L675)
- [ ] End does not affect child spans — [L662-L663](references/opentelemetry-specification-v1.55.0/trace/api.md#L662)
- [ ] End does not inactivate span in any Context — [L665-L668](references/opentelemetry-specification-v1.55.0/trace/api.md#L665)
- [ ] RecordException: specialized AddEvent for exceptions (optional per language) — [L684-L705](references/opentelemetry-specification-v1.55.0/trace/api.md#L684)

### Trace API — No-Op Behavior

> Ref: [trace/api.md](references/opentelemetry-specification-v1.55.0/trace/api.md)

- [ ] Without SDK: API is no-op — [L862-L864](references/opentelemetry-specification-v1.55.0/trace/api.md#L862)
- [ ] Return non-recording Span with SpanContext from parent Context — [L865-L868](references/opentelemetry-specification-v1.55.0/trace/api.md#L865)
- [ ] If no parent: return Span with all-zero IDs — [L869-L871](references/opentelemetry-specification-v1.55.0/trace/api.md#L869)

### Trace SDK — TracerProvider

> Ref: [trace/sdk.md](references/opentelemetry-specification-v1.55.0/trace/sdk.md)

- [ ] Specify Resource at creation — [L110-L115](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L110)
- [ ] Configure SpanProcessors, IdGenerator, SpanLimits, Sampler — [L110-L115](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L110)
- [ ] Shutdown: call once, invoke Shutdown on all processors — [L159-L173](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L159)
- [ ] Shutdown: return success/failure/timeout indication — [L165-L166](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L165)
- [ ] After shutdown: return no-op Tracers — [L162-L163](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L162)
- [ ] ForceFlush: invoke ForceFlush on all registered SpanProcessors — [L187](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L187)
- [ ] ForceFlush: return success/failure/timeout indication — [L179-L180](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L179)
- [ ] Thread-safe for Tracer creation, ForceFlush, Shutdown — [L1281](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1281)

### Trace SDK — Span Limits

> Ref: [trace/sdk.md](references/opentelemetry-specification-v1.55.0/trace/sdk.md), [configuration/sdk-environment-variables.md](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md)

- [ ] `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT` — per-span attribute value length — [L190](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L190)
- [ ] `OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT` — max span attributes (default: 128) — [L191](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L191)
- [ ] `OTEL_SPAN_EVENT_COUNT_LIMIT` — max span events (default: 128) — [L192](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L192)
- [ ] `OTEL_SPAN_LINK_COUNT_LIMIT` — max span links (default: 128) — [L193](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L193)
- [ ] `OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT` — max attributes per event (default: 128) — [L194](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L194)
- [ ] `OTEL_LINK_ATTRIBUTE_COUNT_LIMIT` — max attributes per link (default: 128) — [L195](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L195)
- [ ] Log message when limits cause discards (at most once per span) — [L873-L876](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L873)

### Trace SDK — IdGenerator

> Ref: [trace/sdk.md](references/opentelemetry-specification-v1.55.0/trace/sdk.md)

- [ ] Default: randomly generate TraceId (16 bytes) and SpanId (8 bytes) — [L880](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L880)
- [ ] Provide mechanism for custom IdGenerator — [L882-L883](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L882)

### Trace SDK — Samplers

> Ref: [trace/sdk.md](references/opentelemetry-specification-v1.55.0/trace/sdk.md)

- [ ] AlwaysOn: return RECORD_AND_SAMPLE; description "AlwaysOnSampler" — [L423-L426](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L423)
- [ ] AlwaysOff: return DROP; description "AlwaysOffSampler" — [L429-L431](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L429)
- [ ] TraceIdRatioBased: deterministic hash of TraceId; ignore parent SampledFlag — [L447-L466](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L447)
- [ ] TraceIdRatioBased: lower probability is subset of higher probability — [L467-L471](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L467)
- [ ] TraceIdRatioBased: description "TraceIdRatioBased{RATIO}" — [L450-L456](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L450)
- [ ] ParentBased: required `root` sampler parameter — [L575](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L575)
- [ ] ParentBased: optional `remoteParentSampled` (default: AlwaysOn) — [L579](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L579)
- [ ] ParentBased: optional `remoteParentNotSampled` (default: AlwaysOff) — [L580](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L580)
- [ ] ParentBased: optional `localParentSampled` (default: AlwaysOn) — [L581](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L581)
- [ ] ParentBased: optional `localParentNotSampled` (default: AlwaysOff) — [L582](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L582)
- [ ] Sampler ShouldSample and GetDescription must be thread-safe — [L1284-L1285](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1284)

### Trace SDK — SpanProcessor

> Ref: [trace/sdk.md](references/opentelemetry-specification-v1.55.0/trace/sdk.md)

- [ ] OnStart: called synchronously when span starts; must not block/throw — [L963-L967](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L963)
- [ ] OnEnd: called after span ends with readable span — [L1005-L1017](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1005)
- [ ] Shutdown: called once during SDK shutdown — [L1019-L1036](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1019)
- [ ] ForceFlush: ensure span export within timeout — [L1038-L1062](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1038)
- [ ] All methods must be thread-safe — [L1287](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1287)

#### Simple SpanProcessor

- [ ] Pass finished spans to SpanExporter immediately — [L1070-L1074](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1070)
- [ ] Synchronize Export calls (no concurrent invocation) — [L1076-L1077](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1076)

#### Batch SpanProcessor

- [ ] Create batches of spans for export — [L1083-L1087](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1083)
- [ ] Synchronize Export calls (no concurrent invocation) — [L1089-L1090](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1089)
- [ ] Export on scheduledDelayMillis interval (default: 5000) — [L1111-L1112](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1111)
- [ ] Export on maxExportBatchSize threshold (default: 512) — [L1115-L1118](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1115)
- [ ] Export on ForceFlush call — [L1101](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1101)
- [ ] maxQueueSize configuration (default: 2048) — [L1109-L1110](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1109)
- [ ] exportTimeoutMillis configuration (default: 30000) — [L1113-L1114](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1113)
- [ ] `OTEL_BSP_SCHEDULE_DELAY` env var (default: 5000) — [L158](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L158)
- [ ] `OTEL_BSP_EXPORT_TIMEOUT` env var (default: 30000) — [L159](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L159)
- [ ] `OTEL_BSP_MAX_QUEUE_SIZE` env var (default: 2048) — [L160](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L160)
- [ ] `OTEL_BSP_MAX_EXPORT_BATCH_SIZE` env var (default: 512) — [L161](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L161)

### Trace SDK — SpanExporter

> Ref: [trace/sdk.md](references/opentelemetry-specification-v1.55.0/trace/sdk.md)

- [ ] Export: accept batch of spans, return Success or Failure — [L1139-L1182](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1139)
- [ ] Export must not be called concurrently for same instance — [L1146-L1147](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1146)
- [ ] Export must not block indefinitely (reasonable timeout) — [L1156-L1157](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1156)
- [ ] Shutdown: called once; subsequent Export returns Failure — [L1189-L1200](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1189)
- [ ] Shutdown must not block indefinitely — [L1198-L1200](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1198)
- [ ] ForceFlush: hint to complete prior exports promptly — [L1202-L1218](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1202)
- [ ] ForceFlush and Shutdown must be thread-safe — [L1289-L1290](references/opentelemetry-specification-v1.55.0/trace/sdk.md#L1289)

### Console Exporter — Spans

> Ref: [trace/sdk_exporters/stdout.md](references/opentelemetry-specification-v1.55.0/trace/sdk_exporters/stdout.md)

- [ ] Output spans to stdout/console — [L9-L11](references/opentelemetry-specification-v1.55.0/trace/sdk_exporters/stdout.md#L9)
- [ ] Output format is implementation-defined — [L13-L14](references/opentelemetry-specification-v1.55.0/trace/sdk_exporters/stdout.md#L13)
- [ ] Document as debugging/learning tool, not for production — [L17-L19](references/opentelemetry-specification-v1.55.0/trace/sdk_exporters/stdout.md#L17)
- [ ] Default pairing with Simple SpanProcessor — [L30-L35](references/opentelemetry-specification-v1.55.0/trace/sdk_exporters/stdout.md#L30)

## OTLP Exporters

### OTLP Exporter — Common Configuration

> Ref: [protocol/exporter.md](references/opentelemetry-specification-v1.55.0/protocol/exporter.md)

- [ ] `OTEL_EXPORTER_OTLP_ENDPOINT` — base endpoint URL — [L16-L29](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L16)
- [ ] Per-signal endpoint overrides (`*_TRACES_ENDPOINT`, `*_METRICS_ENDPOINT`, `*_LOGS_ENDPOINT`) — [L28](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L28)
- [ ] `OTEL_EXPORTER_OTLP_PROTOCOL` — grpc, http/protobuf, http/json (default: http/protobuf) — [L71-L75](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L71)
- [ ] Per-signal protocol overrides — [L74](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L74)
- [ ] `OTEL_EXPORTER_OTLP_HEADERS` — key-value pairs as request headers — [L56-L59](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L56)
- [ ] Per-signal header overrides — [L58](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L58)
- [ ] `OTEL_EXPORTER_OTLP_COMPRESSION` — gzip or none — [L61-L64](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L61)
- [ ] Per-signal compression overrides — [L63](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L63)
- [ ] `OTEL_EXPORTER_OTLP_TIMEOUT` — per-batch timeout (default: 10s) — [L66-L69](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L66)
- [ ] Per-signal timeout overrides — [L68](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L68)
- [ ] `OTEL_EXPORTER_OTLP_CERTIFICATE` — TLS certificate file — [L41-L44](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L41)
- [ ] Per-signal certificate overrides — [L43](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L43)
- [ ] `OTEL_EXPORTER_OTLP_CLIENT_KEY` — mTLS client private key — [L46-L49](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L46)
- [ ] `OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE` — mTLS client certificate — [L51-L54](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L51)
- [ ] Signal-specific options take precedence over general options — [L14-L15](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L14)
- [ ] Emit User-Agent header (e.g., OTel-OTLP-Exporter-Elixir/VERSION) — [L205-L211](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L205)

### OTLP Protocol — Encoding

> Ref: [protocol/exporter.md](references/opentelemetry-specification-v1.55.0/protocol/exporter.md)

- [ ] Binary Protobuf encoding (Proto3) — [L165](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L165)
- [ ] JSON Protobuf encoding: traceId/spanId as hex (not base64), enum as integers, lowerCamelCase keys — [L167](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L167)
- [ ] Receivers must ignore unknown fields in JSON — [L167](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L167)

### OTLP/HTTP Exporter

> Ref: [protocol/exporter.md](references/opentelemetry-specification-v1.55.0/protocol/exporter.md)

- [ ] Default endpoint: http://localhost:4318 — [L27](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L27)
- [ ] Append signal-specific paths to base endpoint: /v1/traces, /v1/metrics, /v1/logs — [L98-L111](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L98)
- [ ] Per-signal endpoint used as-is (no path appending) — [L101-L103](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L101)
- [ ] HTTP POST requests for sending telemetry — [L165-L166](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L165)
- [ ] Support binary Protobuf (Content-Type: application/x-protobuf) — [L166](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L166)
- [ ] Support JSON Protobuf (Content-Type: application/json) — optional but recommended — [L167](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L167)
- [ ] Support gzip compression (Content-Encoding: gzip) — [L61-L64](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L61)
- [ ] Handle HTTP 200 OK (success) — [L194-L196](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L194)
- [ ] Handle partial success (HTTP 200 with partial_success field) — [L196-L199](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L196)
- [ ] Handle HTTP 400 Bad Request (non-retryable) — [L196-L199](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L196)
- [ ] Handle retryable status codes: 429, 502, 503, 504 — [L194-L199](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L194)
- [ ] Respect Retry-After header on 429/503 — [L194-L199](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L194)
- [ ] Exponential backoff with jitter for retries — [L184](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L184)
- [ ] Must not modify URL beyond specified rules — [L115-L118](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L115)

### OTLP/gRPC Exporter

> Ref: [protocol/exporter.md](references/opentelemetry-specification-v1.55.0/protocol/exporter.md)

- [ ] Default endpoint: http://localhost:4317 — [L32](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L32)
- [ ] Unary RPC calls with Export*ServiceRequest messages — [L165](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L165)
- [ ] Support gzip compression — [L61-L64](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L61)
- [ ] Handle success: Export*ServiceResponse — [L190-L191](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L190)
- [ ] Handle partial success (partial_success field) — [L196-L199](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L196)
- [ ] Handle retryable gRPC status: UNAVAILABLE (with optional RetryInfo) — [L190-L191](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L190)
- [ ] Handle non-retryable gRPC status: INVALID_ARGUMENT — [L190-L191](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L190)
- [ ] Retryable gRPC codes: CANCELLED, DEADLINE_EXCEEDED, ABORTED, OUT_OF_RANGE, UNAVAILABLE, DATA_LOSS — [L190-L191](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L190)
- [ ] Non-retryable gRPC codes: UNKNOWN, INVALID_ARGUMENT, NOT_FOUND, ALREADY_EXISTS, PERMISSION_DENIED, UNAUTHENTICATED, FAILED_PRECONDITION, INTERNAL, UNIMPLEMENTED — [L190-L191](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L190)
- [ ] Exponential backoff with jitter for retries — [L184](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L184)
- [ ] https scheme takes precedence over insecure setting — [L31](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L31)
- [ ] Configurable concurrent request count — [L190-L191](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L190)
- [ ] `OTEL_EXPORTER_OTLP_INSECURE` — transport security (default: false) — [L36-L39](references/opentelemetry-specification-v1.55.0/protocol/exporter.md#L36)

## Metrics

### Metrics API — MeterProvider

> Ref: [metrics/api.md](references/opentelemetry-specification-v1.55.0/metrics/api.md)

- [ ] Provide function to get/create a Meter — [L116-L118](references/opentelemetry-specification-v1.55.0/metrics/api.md#L116)
- [ ] Accept `name` parameter (required) — [L124-L133](references/opentelemetry-specification-v1.55.0/metrics/api.md#L124)
- [ ] Accept optional `version` parameter — [L134-L139](references/opentelemetry-specification-v1.55.0/metrics/api.md#L134)
- [ ] Accept optional `schema_url` parameter — [L140-L145](references/opentelemetry-specification-v1.55.0/metrics/api.md#L140)
- [ ] Accept optional `attributes` parameter (instrumentation scope) — [L146-L151](references/opentelemetry-specification-v1.55.0/metrics/api.md#L146)
- [ ] Return working Meter even for invalid names — [L130-L133](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L130)
- [ ] Provide global default MeterProvider mechanism — [L111-L112](references/opentelemetry-specification-v1.55.0/metrics/api.md#L111)
- [ ] Thread-safe for concurrent use — [L1345-L1346](references/opentelemetry-specification-v1.55.0/metrics/api.md#L1345)

### Metrics API — Meter

> Ref: [metrics/api.md](references/opentelemetry-specification-v1.55.0/metrics/api.md)

- [ ] Provide functions to create all instrument types — [L166-L174](references/opentelemetry-specification-v1.55.0/metrics/api.md#L166)
- [ ] Thread-safe for concurrent use — [L1348-L1349](references/opentelemetry-specification-v1.55.0/metrics/api.md#L1348)

### Metrics API — Instrument General

> Ref: [metrics/api.md](references/opentelemetry-specification-v1.55.0/metrics/api.md)

- [ ] Instrument identity: name, kind, unit, description — [L180-L191](references/opentelemetry-specification-v1.55.0/metrics/api.md#L180)
- [ ] Name: starts with alpha, max 255 chars, case-insensitive — [L201-L218](references/opentelemetry-specification-v1.55.0/metrics/api.md#L201)
- [ ] Name: allows alphanumeric, underscore, period, hyphen, forward slash — [L207-L217](references/opentelemetry-specification-v1.55.0/metrics/api.md#L207)
- [ ] Unit: optional, case-sensitive, max 63 ASCII chars — [L222-L230](references/opentelemetry-specification-v1.55.0/metrics/api.md#L222)
- [ ] Description: optional, supports BMP Unicode, at least 1023 chars — [L234-L243](references/opentelemetry-specification-v1.55.0/metrics/api.md#L234)

### Metrics API — Synchronous Instruments

> Ref: [metrics/api.md](references/opentelemetry-specification-v1.55.0/metrics/api.md)

#### Counter

- [ ] Create with name, optional unit, description, advisory params — [L510-L518](references/opentelemetry-specification-v1.55.0/metrics/api.md#L510)
- [ ] Add: accept non-negative increment value and optional attributes — [L545-L570](references/opentelemetry-specification-v1.55.0/metrics/api.md#L545)
- [ ] Enabled API returning boolean — [L479-L495](references/opentelemetry-specification-v1.55.0/metrics/api.md#L479)

#### UpDownCounter

- [ ] Create with name, optional unit, description, advisory params — [L1084-L1093](references/opentelemetry-specification-v1.55.0/metrics/api.md#L1084)
- [ ] Add: accept positive or negative value and optional attributes — [L1118-L1137](references/opentelemetry-specification-v1.55.0/metrics/api.md#L1118)
- [ ] Enabled API returning boolean — [L479-L495](references/opentelemetry-specification-v1.55.0/metrics/api.md#L479)

#### Histogram

- [ ] Create with name, optional unit, description, advisory params — [L747-L754](references/opentelemetry-specification-v1.55.0/metrics/api.md#L747)
- [ ] Record: accept non-negative value and optional attributes — [L781-L805](references/opentelemetry-specification-v1.55.0/metrics/api.md#L781)
- [ ] Enabled API returning boolean — [L479-L495](references/opentelemetry-specification-v1.55.0/metrics/api.md#L479)

#### Gauge

- [ ] Create with name, optional unit, description, advisory params — [L852-L860](references/opentelemetry-specification-v1.55.0/metrics/api.md#L852)
- [ ] Record: accept value (absolute current) and optional attributes — [L877-L895](references/opentelemetry-specification-v1.55.0/metrics/api.md#L877)
- [ ] Enabled API returning boolean — [L479-L495](references/opentelemetry-specification-v1.55.0/metrics/api.md#L479)

### Metrics API — Asynchronous Instruments

> Ref: [metrics/api.md](references/opentelemetry-specification-v1.55.0/metrics/api.md)

#### Observable Counter

- [ ] Create with name, optional unit, description, advisory params, callbacks — [L613-L629](references/opentelemetry-specification-v1.55.0/metrics/api.md#L613)
- [ ] Callback reports absolute monotonically increasing value — [L631-L634](references/opentelemetry-specification-v1.55.0/metrics/api.md#L631)
- [ ] Support callback registration/unregistration after creation — [L415-L421](references/opentelemetry-specification-v1.55.0/metrics/api.md#L415)

#### Observable UpDownCounter

- [ ] Create with name, optional unit, description, advisory params, callbacks — [L1176-L1193](references/opentelemetry-specification-v1.55.0/metrics/api.md#L1176)
- [ ] Callback reports absolute additive value — [L1195-L1198](references/opentelemetry-specification-v1.55.0/metrics/api.md#L1195)
- [ ] Support callback registration/unregistration after creation — [L415-L421](references/opentelemetry-specification-v1.55.0/metrics/api.md#L415)

#### Observable Gauge

- [ ] Create with name, optional unit, description, advisory params, callbacks — [L934-L950](references/opentelemetry-specification-v1.55.0/metrics/api.md#L934)
- [ ] Callback reports non-additive value — [L919-L922](references/opentelemetry-specification-v1.55.0/metrics/api.md#L919)
- [ ] Support callback registration/unregistration after creation — [L415-L421](references/opentelemetry-specification-v1.55.0/metrics/api.md#L415)

### Metrics API — Callback Requirements

> Ref: [metrics/api.md](references/opentelemetry-specification-v1.55.0/metrics/api.md)

- [ ] Callbacks evaluated exactly once per collection per instrument — [L422-L424](references/opentelemetry-specification-v1.55.0/metrics/api.md#L422)
- [ ] Observations from single callback treated as same instant — [L462-L465](references/opentelemetry-specification-v1.55.0/metrics/api.md#L462)
- [ ] Should be reentrant safe — [L428](references/opentelemetry-specification-v1.55.0/metrics/api.md#L428)
- [ ] Should not make duplicate observations (same attributes) — [L431-L433](references/opentelemetry-specification-v1.55.0/metrics/api.md#L431)

### Metrics SDK — MeterProvider

> Ref: [metrics/sdk.md](references/opentelemetry-specification-v1.55.0/metrics/sdk.md)

- [ ] Specify Resource at creation — [L109-L110](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L109)
- [ ] Configure MetricExporters, MetricReaders, Views — [L142-L146](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L142)
- [ ] Support multiple MetricReader registration (independent operation) — [L1365-L1372](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1365)
- [ ] Shutdown: call once, invoke Shutdown on all MetricReaders and MetricExporters — [L191-L204](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L191)
- [ ] Shutdown: return success/failure/timeout; subsequent meter requests return no-op — [L192-L196](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L192)
- [ ] ForceFlush: invoke on all registered MetricReaders — [L216-L217](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L216)
- [ ] Thread-safe for meter creation, ForceFlush, Shutdown — [L191-L228](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L191)
- [ ] Return working Meter for invalid names (log the issue) — [L130-L133](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L130)

### Metrics SDK — Meter

> Ref: [metrics/sdk.md](references/opentelemetry-specification-v1.55.0/metrics/sdk.md)

- [ ] Validate instrument names on creation — [L960-L963](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L960)
- [ ] Emit error for invalid instrument names — [L965-L967](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L965)
- [ ] Handle duplicate instrument registration (warn, aggregate identical) — [L904-L942](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L904)
- [ ] Case-insensitive name handling: return first-seen casing — [L947-L958](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L947)
- [ ] Null/missing unit and description treated as empty string — [L971-L979](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L971)
- [ ] Advisory parameters: View config takes precedence — [L994-L996](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L994)
- [ ] Instrument Enabled: false when MeterConfig disabled or all Views use Drop — [L1029-L1038](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1029)

### Metrics SDK — Views

> Ref: [metrics/sdk.md](references/opentelemetry-specification-v1.55.0/metrics/sdk.md)

- [ ] Instrument selection criteria: name (exact/wildcard), type, unit, meter_name, meter_version, meter_schema_url — [L259-L324](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L259)
- [ ] Single asterisk matches all instruments — [L275-L289](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L275)
- [ ] Selection criteria are additive (AND logic) — [L264-L268](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L264)
- [ ] Stream configuration: name override, description override — [L340-L361](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L340)
- [ ] Stream configuration: attribute key allow-list/exclude-list — [L362-L383](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L362)
- [ ] Stream configuration: aggregation specification — [L385-L393](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L385)
- [ ] Stream configuration: exemplar_reservoir, aggregation_cardinality_limit — [L394-L416](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L394)
- [ ] No Views registered: apply default aggregation per instrument kind — [L424-L428](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L424)
- [ ] Registered Views: independently apply each matching View — [L429-L446](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L429)
- [ ] No matching View: enable with default aggregation — [L447-L450](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L447)
- [ ] Views not merged; warn on conflicting metric identities — [L433-L443](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L433)

### Metrics SDK — Aggregation

> Ref: [metrics/sdk.md](references/opentelemetry-specification-v1.55.0/metrics/sdk.md)

- [ ] Drop aggregation: ignore all measurements — [L581-L586](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L581)
- [ ] Default aggregation: select per instrument kind — [L589-L604](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L589)
- [ ] Sum aggregation: arithmetic sum of measurements — [L606-L627](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L606)
- [ ] Last Value aggregation: last measurement with timestamp — [L629-L639](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L629)
- [ ] Explicit Bucket Histogram: count, sum, optional min/max — [L641-L668](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L641)
- [ ] Explicit Bucket Histogram default boundaries: [0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000] — [L661](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L661)
- [ ] Explicit Bucket Histogram RecordMinMax (default: true) — [L662](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L662)
- [ ] Buckets: exclusive of lower bound, inclusive of upper bound — [L664-L668](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L664)

#### Default Aggregation Mapping

- [ ] Counter / Observable Counter -> Sum (monotonic) — [L596-L597](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L596)
- [ ] UpDownCounter / Observable UpDownCounter -> Sum (non-monotonic) — [L598-L599](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L598)
- [ ] Gauge / Observable Gauge -> Last Value — [L600-L601](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L600)
- [ ] Histogram -> Explicit Bucket Histogram — [L602](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L602)

### Metrics SDK — Temporal Aggregation

> Ref: [metrics/sdk.md](references/opentelemetry-specification-v1.55.0/metrics/sdk.md)

- [ ] Cumulative temporality: consistent start timestamp across all collection intervals — [L1353-L1355](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1353)
- [ ] Cumulative: data points persist regardless of new measurements — [L1338-L1341](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1338)
- [ ] Delta temporality: start timestamp advances between collections — [L1356-L1358](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1356)
- [ ] Delta: only data points with measurements since previous collection — [L1341-L1348](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1341)

### Metrics SDK — Cardinality Limits

> Ref: [metrics/sdk.md](references/opentelemetry-specification-v1.55.0/metrics/sdk.md)

- [ ] View-specific limit takes precedence — [L821](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L821)
- [ ] MetricReader default limit applies second — [L824-L826](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L824)
- [ ] Default cardinality limit: 2000 — [L827-L828](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L827)
- [ ] Enforce after attribute filtering — [L813-L815](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L813)
- [ ] Overflow aggregator with attribute `otel.metric.overflow=true` — [L832-L842](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L832)
- [ ] Every measurement reflected exactly once (no double-counting/dropping) — [L856-L862](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L856)

### Metrics SDK — Exemplars

> Ref: [metrics/sdk.md](references/opentelemetry-specification-v1.55.0/metrics/sdk.md)

- [ ] Exemplar sampling on by default — [L1103-L1104](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1103)
- [ ] ExemplarFilter: AlwaysOn, AlwaysOff, TraceBased (default) — [L1115-L1131](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1115)
- [ ] Configurable ExemplarReservoir per View — [L1280-L1286](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1280)
- [ ] ExemplarReservoir: offer (value, attributes, context, timestamp) — [L1155-L1162](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1155)
- [ ] ExemplarReservoir: collect (respect aggregation temporality) — [L1179-L1184](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1179)
- [ ] Return attributes not already in metric data point — [L1186-L1190](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1186)
- [ ] SimpleFixedSizeExemplarReservoir: uniform sampling (default for most) — [L1216-L1242](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1216)
- [ ] AlignedHistogramBucketExemplarReservoir: one per bucket (default for histograms) — [L1244-L1278](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1244)
- [ ] Thread-safe ExemplarReservoir methods — [L1192](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1192)

### Metrics SDK — MetricReader

> Ref: [metrics/sdk.md](references/opentelemetry-specification-v1.55.0/metrics/sdk.md)

- [ ] Configure: exporter, default aggregation, output temporality, cardinality limit — [L1301-L1309](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1301)
- [ ] Optional: MetricProducers, MetricFilter — [L1308-L1309](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1308)
- [ ] Collect: gather metrics from SDK and MetricProducers — [L1399-L1424](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1399)
- [ ] Collect: trigger asynchronous instrument callbacks — [L1403-L1404](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1403)
- [ ] Collect: return success/failure/timeout — [L1406-L1409](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1406)
- [ ] Shutdown: call once; subsequent Collect not allowed — [L1428-L1432](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1428)
- [ ] Support multiple MetricReaders on same MeterProvider (independent) — [L1365-L1372](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1365)
- [ ] MetricReader must not be registered on multiple MeterProviders — [L1374-L1375](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1374)

#### Periodic Exporting MetricReader

- [ ] exportIntervalMillis configuration (default: 60000) — [L1450-L1451](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1450)
- [ ] exportTimeoutMillis configuration (default: 30000) — [L1452-L1453](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1452)
- [ ] Collect metrics on configurable interval — [L1442-L1453](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1442)
- [ ] Synchronize exporter calls (no concurrent invocation) — [L1455-L1456](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1455)
- [ ] ForceFlush: collect and export immediately — [L1473-L1490](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1473)

### Metrics SDK — MetricExporter (Push)

> Ref: [metrics/sdk.md](references/opentelemetry-specification-v1.55.0/metrics/sdk.md)

- [ ] Export: accept metrics, return Success or Failure — [L1559-L1618](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1559)
- [ ] Export must not be called concurrently for same instance — [L1568-L1569](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1568)
- [ ] Export must not block indefinitely — [L1571-L1572](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1571)
- [ ] Shutdown: call once; subsequent Export returns Failure — [L1641-L1652](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1641)
- [ ] Shutdown must not block indefinitely — [L1650-L1652](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1650)
- [ ] ForceFlush: hint to complete prior exports — [L1623-L1639](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1623)
- [ ] ForceFlush and Shutdown must be thread-safe — [L1641-L1652](references/opentelemetry-specification-v1.55.0/metrics/sdk.md#L1641)

### Console Exporter — Metrics

> Ref: [metrics/sdk_exporters/stdout.md](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md)

- [ ] Output metrics to stdout/console — [L9-L11](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md#L9)
- [ ] Output format is implementation-defined — [L13-L14](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md#L13)
- [ ] Document as debugging/learning tool, not for production — [L17-L19](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md#L17)
- [ ] Default temporality: Cumulative for all instrument kinds — [L30-L33](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md#L30)
- [ ] Pair with Periodic Exporting MetricReader (default interval: 10000ms) — [L40-L46](references/opentelemetry-specification-v1.55.0/metrics/sdk_exporters/stdout.md#L40)

## Logs

### Logs API — LoggerProvider

> Ref: [logs/api.md](references/opentelemetry-specification-v1.55.0/logs/api.md)

- [ ] Provide function to get a Logger — [L64-L66](references/opentelemetry-specification-v1.55.0/logs/api.md#L64)
- [ ] Accept `name` parameter (required) — [L73-L83](references/opentelemetry-specification-v1.55.0/logs/api.md#L73)
- [ ] Accept optional `version`, `schema_url`, `attributes` parameters — [L85-L93](references/opentelemetry-specification-v1.55.0/logs/api.md#L85)
- [ ] Provide global default LoggerProvider mechanism — [L59-L60](references/opentelemetry-specification-v1.55.0/logs/api.md#L59)
- [ ] Thread-safe for concurrent use — [L172-L173](references/opentelemetry-specification-v1.55.0/logs/api.md#L172)

### Logs API — Logger

> Ref: [logs/api.md](references/opentelemetry-specification-v1.55.0/logs/api.md)

- [ ] Provide function to emit LogRecord — [L103-L105](references/opentelemetry-specification-v1.55.0/logs/api.md#L103)
- [ ] Accept optional: Timestamp, Observed Timestamp, Context, Severity Number, Severity Text, Body, Attributes, Event Name — [L115-L128](references/opentelemetry-specification-v1.55.0/logs/api.md#L115)
- [ ] Provide Enabled API returning boolean — [L133-L154](references/opentelemetry-specification-v1.55.0/logs/api.md#L133)
- [ ] Enabled accepts optional: Context, Severity Number, Event Name — [L138-L145](references/opentelemetry-specification-v1.55.0/logs/api.md#L138)
- [ ] Thread-safe for concurrent use — [L175-L176](references/opentelemetry-specification-v1.55.0/logs/api.md#L175)

### Logs SDK — LoggerProvider

> Ref: [logs/sdk.md](references/opentelemetry-specification-v1.55.0/logs/sdk.md)

- [ ] Specify Resource at creation — [L59-L61](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L59)
- [ ] Configure LogRecordProcessors — [L90-L101](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L90)
- [ ] Updated configuration applies to all existing Loggers — [L95-L101](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L95)
- [ ] Shutdown: call once; subsequent Logger retrieval not allowed — [L140-L142](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L140)
- [ ] Shutdown: invoke Shutdown on all registered LogRecordProcessors — [L152-L153](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L152)
- [ ] ForceFlush: invoke ForceFlush on all registered LogRecordProcessors — [L172-L173](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L172)
- [ ] Thread-safe for Logger creation, ForceFlush, Shutdown — [L654-L655](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L654)

### Logs SDK — Logger

> Ref: [logs/sdk.md](references/opentelemetry-specification-v1.55.0/logs/sdk.md)

- [ ] Set ObservedTimestamp to current time if unspecified — [L225-L226](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L225)
- [ ] Apply exception semantic conventions to exception attributes — [L228-L230](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L228)
- [ ] User-provided attributes must not be overwritten by exception-derived attributes — [L231-L232](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L231)
- [ ] Thread-safe for all methods — [L657](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L657)

### Logs SDK — LogRecord Limits

> Ref: [logs/sdk.md](references/opentelemetry-specification-v1.55.0/logs/sdk.md), [configuration/sdk-environment-variables.md](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md)

- [ ] Configurable attribute count limit — [L321-L343](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L321)
- [ ] Configurable attribute value length limit — [L321-L343](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L321)
- [ ] `OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT` env var — [L203](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L203)
- [ ] `OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT` env var (default: 128) — [L204](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md#L204)
- [ ] Log message when attributes discarded (at most once per LogRecord) — [L345-L348](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L345)

### Logs SDK — LogRecordProcessor

> Ref: [logs/sdk.md](references/opentelemetry-specification-v1.55.0/logs/sdk.md)

- [ ] OnEmit: called synchronously; must not block/throw — [L393-L397](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L393)
- [ ] LogRecord mutations visible to next registered processors — [L408-L409](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L408)
- [ ] Shutdown: call once; subsequent OnEmit not allowed — [L457-L464](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L457)
- [ ] ForceFlush: complete or abort within timeout — [L476-L503](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L476)
- [ ] Thread-safe for all methods — [L649-L661](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L649)

#### Simple LogRecordProcessor

- [ ] Pass finished LogRecords to LogRecordExporter immediately — [L514-L519](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L514)
- [ ] Synchronize Export calls (no concurrent invocation) — [L521-L522](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L521)

#### Batch LogRecordProcessor

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

### Logs SDK — LogRecordExporter

> Ref: [logs/sdk.md](references/opentelemetry-specification-v1.55.0/logs/sdk.md)

- [ ] Export: accept batch of LogRecords, return Success or Failure — [L566-L612](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L566)
- [ ] Export must not be called concurrently for same instance — [L572-L573](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L572)
- [ ] Export must not block indefinitely — [L582-L583](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L582)
- [ ] Shutdown: call once; subsequent Export returns Failure — [L632-L639](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L632)
- [ ] ForceFlush and Shutdown must be thread-safe — [L659-L660](references/opentelemetry-specification-v1.55.0/logs/sdk.md#L659)

### Console Exporter — Logs

> Ref: [logs/sdk_exporters/stdout.md](references/opentelemetry-specification-v1.55.0/logs/sdk_exporters/stdout.md)

- [ ] Output LogRecords to stdout/console — [L9-L10](references/opentelemetry-specification-v1.55.0/logs/sdk_exporters/stdout.md#L9)
- [ ] Output format is implementation-defined — [L12-L13](references/opentelemetry-specification-v1.55.0/logs/sdk_exporters/stdout.md#L12)
- [ ] Document as debugging/learning tool, not for production — [L16-L18](references/opentelemetry-specification-v1.55.0/logs/sdk_exporters/stdout.md#L16)
- [ ] Default pairing with Simple LogRecordProcessor — [L29-L34](references/opentelemetry-specification-v1.55.0/logs/sdk_exporters/stdout.md#L29)

## Environment Variables

> Ref: [configuration/sdk-environment-variables.md](references/opentelemetry-specification-v1.55.0/configuration/sdk-environment-variables.md)

General SDK configuration. Applied across all phases.

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
