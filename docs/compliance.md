# OpenTelemetry Specification Compliance

Stable specification items only. Check items as they are implemented.

References:
- [opentelemetry-specification v1.55.0](references/opentelemetry-specification/v1.55.0/README.md)
- [opentelemetry-proto v1.10.0](references/opentelemetry-proto/v1.10.0/docs/specification.md)

## Common

> Ref: [common/README.md](references/opentelemetry-specification/v1.55.0/common/README.md)

### AnyValue
- [ ] Homogeneous array MUST NOT contain values of different types — [L45](references/opentelemetry-specification/v1.55.0/common/README.md#L45)
- [ ] APIs SHOULD be documented that using array and map values may carry higher performance overhead — [L56](references/opentelemetry-specification/v1.55.0/common/README.md#L56)
- [ ] Empty value, zero, empty string, or empty array are meaningful and MUST be stored and passed on to processors/exporters — [L60](references/opentelemetry-specification/v1.55.0/common/README.md#L60)
- [ ] `null` values within arrays SHOULD generally be avoided unless language constraints make this impossible — [L64](references/opentelemetry-specification/v1.55.0/common/README.md#L64)
- [ ] If impossible to prevent null in arrays, null values MUST be preserved as-is — [L67](references/opentelemetry-specification/v1.55.0/common/README.md#L67)

### map<string, AnyValue>
- [ ] Case sensitivity of keys MUST be preserved — [L80](references/opentelemetry-specification/v1.55.0/common/README.md#L80)
- [ ] Implementation MUST by default enforce that exported maps contain only unique keys — [L85](references/opentelemetry-specification/v1.55.0/common/README.md#L85)
- [ ] If option to allow duplicate keys is provided, it MUST be documented that handling is unpredictable — [L93](references/opentelemetry-specification/v1.55.0/common/README.md#L93)

### AnyValue Representation for Non-OTLP Protocols
- [ ] Values SHOULD be represented as strings following the encoding rules — [L103](references/opentelemetry-specification/v1.55.0/common/README.md#L103)
- [ ] Strings SHOULD be represented as-is without additional encoding — [L113](references/opentelemetry-specification/v1.55.0/common/README.md#L113)
- [ ] Strings SHOULD NOT be encoded as JSON strings (with surrounding quotes) — [L114](references/opentelemetry-specification/v1.55.0/common/README.md#L114)
- [ ] Booleans SHOULD be represented as JSON booleans — [L120](references/opentelemetry-specification/v1.55.0/common/README.md#L120)
- [ ] Integers SHOULD be represented as JSON numbers — [L127](references/opentelemetry-specification/v1.55.0/common/README.md#L127)
- [ ] Floating point numbers SHOULD be represented as JSON numbers — [L134](references/opentelemetry-specification/v1.55.0/common/README.md#L134)
- [ ] NaN and Infinity SHOULD be represented as `NaN`, `Infinity`, `-Infinity` — [L137](references/opentelemetry-specification/v1.55.0/common/README.md#L137)
- [ ] NaN/Infinity SHOULD NOT be encoded as JSON strings — [L139](references/opentelemetry-specification/v1.55.0/common/README.md#L139)
- [ ] Byte arrays SHOULD be Base64-encoded — [L145](references/opentelemetry-specification/v1.55.0/common/README.md#L145)
- [ ] Byte arrays SHOULD NOT be encoded as JSON strings — [L146](references/opentelemetry-specification/v1.55.0/common/README.md#L146)
- [ ] Empty values SHOULD be represented as the empty string — [L152](references/opentelemetry-specification/v1.55.0/common/README.md#L152)
- [ ] Empty values SHOULD NOT be encoded as JSON string — [L153](references/opentelemetry-specification/v1.55.0/common/README.md#L153)
- [ ] Arrays SHOULD be represented as JSON arrays — [L157](references/opentelemetry-specification/v1.55.0/common/README.md#L157)
- [ ] Nested byte arrays SHOULD be represented as Base64-encoded JSON strings — [L159](references/opentelemetry-specification/v1.55.0/common/README.md#L159)
- [ ] Nested empty values SHOULD be represented as JSON null — [L161](references/opentelemetry-specification/v1.55.0/common/README.md#L161)
- [ ] Nested NaN/Infinity in arrays SHOULD be represented as JSON strings — [L162](references/opentelemetry-specification/v1.55.0/common/README.md#L162)
- [ ] Maps SHOULD be represented as JSON objects — [L169](references/opentelemetry-specification/v1.55.0/common/README.md#L169)
- [ ] Nested byte arrays in maps SHOULD be Base64-encoded JSON strings — [L171](references/opentelemetry-specification/v1.55.0/common/README.md#L171)
- [ ] Nested empty values in maps SHOULD be JSON null — [L173](references/opentelemetry-specification/v1.55.0/common/README.md#L173)
- [ ] Nested NaN/Infinity in maps SHOULD be JSON strings — [L174](references/opentelemetry-specification/v1.55.0/common/README.md#L174)

### Attribute
- [ ] Attribute MUST have key-value pair properties — [L183](references/opentelemetry-specification/v1.55.0/common/README.md#L183)
- [ ] Attribute key MUST be a non-null and non-empty string — [L185](references/opentelemetry-specification/v1.55.0/common/README.md#L185)
- [ ] Attribute value MUST be one of types defined in AnyValue — [L187](references/opentelemetry-specification/v1.55.0/common/README.md#L187)

### Attribute Collections
- [ ] Implementation MUST by default enforce that exported attribute collections contain only unique keys — [L215](references/opentelemetry-specification/v1.55.0/common/README.md#L215)
- [ ] Setting attribute with same key SHOULD overwrite existing value — [L223](references/opentelemetry-specification/v1.55.0/common/README.md#L223)
- [ ] If option to allow duplicate keys is provided, it MUST be documented that handling is unpredictable — [L241](references/opentelemetry-specification/v1.55.0/common/README.md#L241)

### Attribute Limits
- [ ] SDK SHOULD apply truncation as per configurable parameters by default — [L255](references/opentelemetry-specification/v1.55.0/common/README.md#L255)
- [ ] If string value exceeds length limit, SDKs MUST truncate to at most the limit — [L263](references/opentelemetry-specification/v1.55.0/common/README.md#L263)
- [ ] If byte array exceeds length limit, SDKs MUST truncate to at most the limit — [L267](references/opentelemetry-specification/v1.55.0/common/README.md#L267)
- [ ] A value that is not a string or byte array MUST NOT be truncated — [L274](references/opentelemetry-specification/v1.55.0/common/README.md#L274)
- [ ] If adding attribute exceeds count limit, SDK MUST discard that attribute — [L278](references/opentelemetry-specification/v1.55.0/common/README.md#L278)
- [ ] If attribute is not over count limit, it MUST NOT be discarded — [L282](references/opentelemetry-specification/v1.55.0/common/README.md#L282)
- [ ] Log about truncation/discard MUST NOT be emitted more than once per record — [L285](references/opentelemetry-specification/v1.55.0/common/README.md#L285)
- [ ] If SDK implements limits, it MUST provide a way to change them programmatically — [L288](references/opentelemetry-specification/v1.55.0/common/README.md#L288)
- [ ] Configuration option names SHOULD be the same as listed — [L289](references/opentelemetry-specification/v1.55.0/common/README.md#L289)
- [ ] If both general and model-specific limit exist, SDK MUST first attempt model-specific, then general — [L294](references/opentelemetry-specification/v1.55.0/common/README.md#L294)
- [ ] If neither are defined, SDK MUST try model-specific default, then global default — [L296](references/opentelemetry-specification/v1.55.0/common/README.md#L296)
- [ ] `AttributeCountLimit` default=128, `AttributeValueLengthLimit` default=Infinity — [L305](references/opentelemetry-specification/v1.55.0/common/README.md#L305)
- [ ] Resource attributes SHOULD be exempt from attribute limits — [L310](references/opentelemetry-specification/v1.55.0/common/README.md#L310)

## Context

> Ref: [context/README.md](references/opentelemetry-specification/v1.55.0/context/README.md)

### Overview
- [ ] Context MUST be immutable, write operations MUST result in new Context — [L37](references/opentelemetry-specification/v1.55.0/context/README.md#L37)

### Create a Key
- [ ] API MUST accept the key name parameter — [L65](references/opentelemetry-specification/v1.55.0/context/README.md#L65)
- [ ] Multiple calls to CreateKey with same name SHOULD NOT return same value — [L65](references/opentelemetry-specification/v1.55.0/context/README.md#L65)
- [ ] API MUST return an opaque object representing the newly created key — [L67](references/opentelemetry-specification/v1.55.0/context/README.md#L67)

### Get Value
- [ ] API MUST accept the Context and the key parameters — [L74](references/opentelemetry-specification/v1.55.0/context/README.md#L74)
- [ ] API MUST return the value in the Context for the specified key — [L79](references/opentelemetry-specification/v1.55.0/context/README.md#L79)

### Set Value
- [ ] API MUST accept the Context, key, and value parameters — [L86](references/opentelemetry-specification/v1.55.0/context/README.md#L86)
- [ ] API MUST return a new Context containing the new value — [L92](references/opentelemetry-specification/v1.55.0/context/README.md#L92)

### Optional Global Operations
- [ ] These operations SHOULD only be used to implement automatic scope switching by SDK components — [L98](references/opentelemetry-specification/v1.55.0/context/README.md#L98)
- [ ] Get current Context: API MUST return the Context associated with caller's current execution unit — [L103](references/opentelemetry-specification/v1.55.0/context/README.md#L103)
- [ ] Attach Context: API MUST accept the Context parameter — [L109](references/opentelemetry-specification/v1.55.0/context/README.md#L109)
- [ ] Attach Context: API MUST return a value that can be used as Token — [L113](references/opentelemetry-specification/v1.55.0/context/README.md#L113)
- [ ] Detach Context: API MUST accept a Token parameter — [L133](references/opentelemetry-specification/v1.55.0/context/README.md#L133)

## API Propagators

> Ref: [context/api-propagators.md](references/opentelemetry-specification/v1.55.0/context/api-propagators.md)

### Operations
- [ ] Propagators MUST define Inject and Extract operations — [L83](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L83)
- [ ] Each Propagator type MUST define the specific carrier type — [L84](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L84)
- [ ] Inject: Propagator MUST retrieve appropriate value from Context first — [L93](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L93)
- [ ] Extract: implementation MUST NOT throw an exception on parse failure — [L102](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L102)
- [ ] Extract: MUST NOT store a new value in Context on parse failure — [L102](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L102)

### TextMap Propagator
- [ ] Key/value pairs MUST only consist of US-ASCII characters valid for HTTP header fields (RFC 9110) — [L122](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L122)
- [ ] Getter and Setter MUST be stateless and allowed to be saved as constants — [L130](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L130)
- [ ] Setter Set: implementation SHOULD preserve casing if protocol is case insensitive, otherwise MUST preserve casing — [L183](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L183)
- [ ] Getter Keys: MUST return list of all keys in carrier — [L209](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L209)
- [ ] Getter Get: MUST return first value of given key or null — [L223](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L223)
- [ ] Getter Get: MUST be case insensitive for HTTP requests — [L230](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L230)
- [ ] GetAll (if implemented): MUST return all values of given propagation key — [L240](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L240)
- [ ] GetAll: SHOULD return values in same order as carrier — [L241](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L241)
- [ ] GetAll: SHOULD return empty collection if key doesn't exist — [L242](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L242)
- [ ] GetAll: MUST be case insensitive for HTTP requests — [L249](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L249)

### Composite Propagator
- [ ] Implementations MUST offer facility to group multiple Propagators as single entity — [L261](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L261)
- [ ] There MUST be functions for: create, extract, inject on composite propagator — [L272](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L272)

### Global Propagators
- [ ] API MUST provide a way to obtain a propagator for each supported type — [L310](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L310)
- [ ] Instrumentation libraries SHOULD call propagators to extract/inject context on all remote calls — [L311](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L311)
- [ ] API MUST use no-op propagators unless explicitly configured otherwise — [L322](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L322)
- [ ] Pre-configured Propagators SHOULD default to composite with W3C Trace Context + Baggage — [L329](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L329)
- [ ] Platforms with pre-configured propagators MUST allow them to be disabled or overridden — [L332](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L332)
- [ ] Get Global Propagator: method MUST exist for each supported type — [L336](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L336)
- [ ] Set Global Propagator: method MUST exist for each supported type — [L342](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L342)

### Propagators Distribution
- [ ] W3C TraceContext and W3C Baggage MUST be maintained and distributed — [L352](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L352)

### W3C Trace Context Requirements
- [ ] MUST parse and validate `traceparent` and `tracestate` per W3C Trace Context Level 2 — [L383](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L383)
- [ ] MUST propagate valid `traceparent` using same header — [L383](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L383)
- [ ] MUST propagate valid `tracestate` unless empty — [L383](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L383)

### B3 Requirements
- [ ] B3 Extract: MUST attempt to extract from both single and multi-header formats — [L404](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L404)
- [ ] B3 Extract: MUST preserve debug trace flag and propagate with subsequent requests — [L407](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L407)
- [ ] B3 Extract: implementation MUST set sampled trace flag when debug flag is set — [L409](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L409)
- [ ] B3 Extract: MUST NOT reuse X-B3-SpanId as server-side span id — [L410](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L410)
- [ ] B3 Inject: MUST default to single-header format — [L416](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L416)
- [ ] B3 Inject: MUST provide configuration to change default to multi-header — [L417](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L417)
- [ ] B3 Inject: MUST NOT propagate X-B3-ParentSpanId — [L419](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L419)
- [ ] B3 Fields: MUST return header names corresponding to configured format — [L424](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L424)

## Baggage

> Ref: [baggage/api.md](references/opentelemetry-specification/v1.55.0/baggage/api.md)

### Overview
- [ ] Each name MUST be associated with exactly one value — [L38](references/opentelemetry-specification/v1.55.0/baggage/api.md#L38)
- [ ] Baggage names: Language API SHOULD NOT restrict which strings are used — [L43](references/opentelemetry-specification/v1.55.0/baggage/api.md#L43)
- [ ] Baggage values: Language API MUST accept any valid UTF-8 string and return same from Get — [L53](references/opentelemetry-specification/v1.55.0/baggage/api.md#L53)
- [ ] Language API MUST treat both names and values as case sensitive — [L57](references/opentelemetry-specification/v1.55.0/baggage/api.md#L57)
- [ ] Baggage API MUST be fully functional without installed SDK — [L79](references/opentelemetry-specification/v1.55.0/baggage/api.md#L79)
- [ ] Baggage container MUST be immutable — [L84](references/opentelemetry-specification/v1.55.0/baggage/api.md#L84)

### Operations
- [ ] Get Value: MUST provide function that takes name and returns value or null — [L92](references/opentelemetry-specification/v1.55.0/baggage/api.md#L92)
- [ ] Get All Values: order MUST NOT be significant — [L102](references/opentelemetry-specification/v1.55.0/baggage/api.md#L102)
- [ ] Set Value: MUST provide function taking name and value, returns new Baggage — [L108](references/opentelemetry-specification/v1.55.0/baggage/api.md#L108)
- [ ] Remove Value: MUST provide function taking name, returns new Baggage — [L128](references/opentelemetry-specification/v1.55.0/baggage/api.md#L128)

### Context Interaction
- [ ] If not operating directly on Context, MUST provide extract/insert Baggage from/to Context — [L144](references/opentelemetry-specification/v1.55.0/baggage/api.md#L144)
- [ ] Users SHOULD NOT have access to Context Key used by Baggage API — [L149](references/opentelemetry-specification/v1.55.0/baggage/api.md#L149)
- [ ] If implicit Context supported, API SHOULD provide get/set currently active Baggage — [L154](references/opentelemetry-specification/v1.55.0/baggage/api.md#L154)
- [ ] This functionality SHOULD be fully implemented in the API when possible — [L166](references/opentelemetry-specification/v1.55.0/baggage/api.md#L166)

### Clear Baggage
- [ ] MUST provide a way to remove all baggage entries from a context — [L172](references/opentelemetry-specification/v1.55.0/baggage/api.md#L172)

### Propagation
- [ ] API layer or extension MUST include a TextMapPropagator implementing W3C Baggage — [L184](references/opentelemetry-specification/v1.55.0/baggage/api.md#L184)

### Conflict Resolution
- [ ] If new name/value pair has same name as existing, new pair MUST take precedence — [L207](references/opentelemetry-specification/v1.55.0/baggage/api.md#L207)

## Resource

> Ref: [resource/sdk.md](references/opentelemetry-specification/v1.55.0/resource/sdk.md)

### Resource SDK
- [ ] SDK MUST allow for creation of Resources and associating them with telemetry — [L22](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L22)
- [ ] All Spans produced by any Tracer from provider MUST be associated with Resource — [L29](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L29)

### SDK-provided Resource Attributes
- [ ] SDK MUST provide access to Resource with at least SDK-provided default value attributes — [L39](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L39)
- [ ] This resource MUST be associated with TracerProvider/MeterProvider if no other resource specified — [L41](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L41)

### Create
- [ ] Interface MUST provide way to create new resource from Attributes — [L58](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L58)

### Merge
- [ ] Interface MUST provide way to merge old and updating resource into new resource — [L71](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L71)
- [ ] Resulting resource MUST have all attributes from both input resources — [L78](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L78)
- [ ] If key exists on both, value of updating resource MUST be picked — [L79](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L79)

### Detecting Resource Information
- [ ] Custom resource detectors for generic platforms MUST be implemented as separate packages — [L107](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L107)
- [ ] Resource detector packages MUST provide method that returns a resource — [L110](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L110)
- [ ] Failure to detect resource info MUST NOT be considered an error — [L122](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L122)
- [ ] Error during detection attempt SHOULD be considered an error — [L123](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L123)
- [ ] Detectors populating semconv attributes MUST ensure Schema URL matches — [L127](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L127)
- [ ] Empty Schema URL SHOULD be used if detector doesn't populate known semconv attributes — [L128](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L128)
- [ ] Multiple detectors with different non-empty Schema URLs MUST be an error — [L133](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L133)

### Environment Variable Resource
- [ ] SDK MUST extract info from OTEL_RESOURCE_ATTRIBUTES and merge as secondary resource — [L179](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L179)
- [ ] All attribute values MUST be considered strings — [L186](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L186)
- [ ] The `,` and `=` characters in keys and values MUST be percent encoded — [L187](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L187)
- [ ] On decoding error, entire value SHOULD be discarded and error SHOULD be reported — [L192](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L192)

## Trace API

> Ref: [trace/api.md](references/opentelemetry-specification/v1.55.0/trace/api.md)

### TracerProvider

- [ ] API SHOULD provide a way to set/register and access a global default TracerProvider — [L96](references/opentelemetry-specification/v1.55.0/trace/api.md#L96)
- [ ] Implementations of TracerProvider SHOULD allow creating an arbitrary number of TracerProvider instances — [L104](references/opentelemetry-specification/v1.55.0/trace/api.md#L104)
- [ ] TracerProvider MUST provide the function: Get a Tracer — [L109](references/opentelemetry-specification/v1.55.0/trace/api.md#L109)

### Get a Tracer

- [ ] Get a Tracer API MUST accept `name` parameter — [L115](references/opentelemetry-specification/v1.55.0/trace/api.md#L115)
- [ ] `name` SHOULD uniquely identify the instrumentation scope — [L117](references/opentelemetry-specification/v1.55.0/trace/api.md#L117)
- [ ] If invalid name (null or empty string), a working Tracer MUST be returned as fallback rather than returning null or throwing an exception — [L126](references/opentelemetry-specification/v1.55.0/trace/api.md#L126)
- [ ] If invalid name, Tracer's `name` property SHOULD be set to an empty string — [L128](references/opentelemetry-specification/v1.55.0/trace/api.md#L128)
- [ ] If invalid name, a message reporting that the specified value is invalid SHOULD be logged — [L129](references/opentelemetry-specification/v1.55.0/trace/api.md#L129)
- [ ] Implementations MUST NOT require users to repeatedly obtain a Tracer with the same identity to pick up configuration changes — [L146](references/opentelemetry-specification/v1.55.0/trace/api.md#L146)

### Context Interaction

- [ ] API MUST provide functionality to extract the Span from a Context instance — [L164](references/opentelemetry-specification/v1.55.0/trace/api.md#L164)
- [ ] API MUST provide functionality to combine the Span with a Context instance, creating a new Context instance — [L164](references/opentelemetry-specification/v1.55.0/trace/api.md#L164)
- [ ] API users SHOULD NOT have access to the Context Key used by the Tracing API implementation — [L170](references/opentelemetry-specification/v1.55.0/trace/api.md#L170)
- [ ] If language has implicit Context propagation, API SHOULD provide get currently active span from implicit context — [L174](references/opentelemetry-specification/v1.55.0/trace/api.md#L174)
- [ ] If language has implicit Context propagation, API SHOULD provide set currently active span into implicit context — [L174](references/opentelemetry-specification/v1.55.0/trace/api.md#L174)
- [ ] Context interaction functionality SHOULD be fully implemented in the API when possible — [L182](references/opentelemetry-specification/v1.55.0/trace/api.md#L182)

### Tracer

- [ ] Tracer MUST provide function to create a new Span — [L193](references/opentelemetry-specification/v1.55.0/trace/api.md#L193)
- [ ] Tracer SHOULD provide function to report if Tracer is Enabled — [L197](references/opentelemetry-specification/v1.55.0/trace/api.md#L197)

### SpanContext

- [ ] API MUST implement methods to create a SpanContext — [L252](references/opentelemetry-specification/v1.55.0/trace/api.md#L252)
- [ ] SpanContext creation functionality MUST be fully implemented in the API — [L253](references/opentelemetry-specification/v1.55.0/trace/api.md#L253)
- [ ] SpanContext creation SHOULD NOT be overridable — [L253](references/opentelemetry-specification/v1.55.0/trace/api.md#L253)

### Retrieving the TraceId and SpanId

- [ ] API MUST allow retrieving the TraceId and SpanId in Hex and Binary forms — [L258](references/opentelemetry-specification/v1.55.0/trace/api.md#L258)
- [ ] Hex TraceId MUST be a 32-hex-character lowercase string — [L261](references/opentelemetry-specification/v1.55.0/trace/api.md#L261)
- [ ] Hex SpanId MUST be a 16-hex-character lowercase string — [L262](references/opentelemetry-specification/v1.55.0/trace/api.md#L262)
- [ ] Binary TraceId MUST be a 16-byte array — [L263](references/opentelemetry-specification/v1.55.0/trace/api.md#L263)
- [ ] Binary SpanId MUST be an 8-byte array — [L264](references/opentelemetry-specification/v1.55.0/trace/api.md#L264)
- [ ] API SHOULD NOT expose details about how TraceId/SpanId are internally stored — [L266](references/opentelemetry-specification/v1.55.0/trace/api.md#L266)

### IsValid

- [ ] An API called IsValid MUST be provided that returns true if SpanContext has a non-zero TraceID and non-zero SpanID — [L270](references/opentelemetry-specification/v1.55.0/trace/api.md#L270)

### IsRemote

- [ ] An API called IsRemote MUST be provided that returns true if SpanContext was propagated from a remote parent — [L275](references/opentelemetry-specification/v1.55.0/trace/api.md#L275)
- [ ] When extracting SpanContext through Propagators API, IsRemote MUST return true — [L278](references/opentelemetry-specification/v1.55.0/trace/api.md#L278)
- [ ] For SpanContext of any child spans, IsRemote MUST return false — [L278](references/opentelemetry-specification/v1.55.0/trace/api.md#L278)

### TraceState

- [ ] Tracing API MUST provide at least: get value for a given key, add a new key/value pair, update an existing value for a given key, delete a key/value pair — [L284](references/opentelemetry-specification/v1.55.0/trace/api.md#L284)
- [ ] TraceState operations MUST follow the rules described in the W3C Trace Context specification — [L291](references/opentelemetry-specification/v1.55.0/trace/api.md#L291)
- [ ] All mutating operations MUST return a new TraceState with the modifications applied — [L292](references/opentelemetry-specification/v1.55.0/trace/api.md#L292)
- [ ] TraceState MUST at all times be valid according to W3C Trace Context specification — [L293](references/opentelemetry-specification/v1.55.0/trace/api.md#L293)
- [ ] Every mutating operation MUST validate input parameters — [L294](references/opentelemetry-specification/v1.55.0/trace/api.md#L294)
- [ ] If invalid value is passed the operation MUST NOT return TraceState containing invalid data and MUST follow general error handling guidelines — [L295](references/opentelemetry-specification/v1.55.0/trace/api.md#L295)

### Span

- [ ] Span name SHOULD be the most general string that identifies a (statistically) interesting class of Spans — [L329](references/opentelemetry-specification/v1.55.0/trace/api.md#L329)
- [ ] Generality SHOULD be prioritized over human-readability — [L333](references/opentelemetry-specification/v1.55.0/trace/api.md#L333)
- [ ] Span's start time SHOULD be set to current time on span creation — [L365](references/opentelemetry-specification/v1.55.0/trace/api.md#L365)
- [ ] After Span is created, it SHOULD be possible to change its name, set Attributes, add Events, and set Status — [L366](references/opentelemetry-specification/v1.55.0/trace/api.md#L366)
- [ ] Name, Attributes, Events, Status MUST NOT be changed after the Span's end time has been set — [L368](references/opentelemetry-specification/v1.55.0/trace/api.md#L368)
- [ ] Implementations SHOULD NOT provide access to a Span's attributes besides its SpanContext — [L371](references/opentelemetry-specification/v1.55.0/trace/api.md#L371)
- [ ] Alternative implementations MUST NOT allow callers to create Spans directly; all Spans MUST be created via a Tracer — [L375](references/opentelemetry-specification/v1.55.0/trace/api.md#L375)

### Span Creation

- [ ] There MUST NOT be any API for creating a Span other than with a Tracer — [L380](references/opentelemetry-specification/v1.55.0/trace/api.md#L380)
- [ ] Span creation MUST NOT set the newly created Span as active Span in current Context by default (for languages with implicit Context propagation) — [L382](references/opentelemetry-specification/v1.55.0/trace/api.md#L382)
- [ ] API MUST accept: span name (required) — [L387](references/opentelemetry-specification/v1.55.0/trace/api.md#L387)
- [ ] API MUST accept: parent Context or indication of root Span — [L390](references/opentelemetry-specification/v1.55.0/trace/api.md#L390)
- [ ] API MUST NOT accept a Span or SpanContext as parent, only a full Context — [L393](references/opentelemetry-specification/v1.55.0/trace/api.md#L393)
- [ ] The semantic parent of the Span MUST be determined according to the rules in Determining the Parent Span from a Context — [L395](references/opentelemetry-specification/v1.55.0/trace/api.md#L395)
- [ ] API documentation MUST state that adding attributes at span creation is preferred to calling SetAttribute later — [L403](references/opentelemetry-specification/v1.55.0/trace/api.md#L403)
- [ ] Start timestamp SHOULD only be set when span creation time has already passed — [L408](references/opentelemetry-specification/v1.55.0/trace/api.md#L408)
- [ ] If API is called at moment of Span logical start, user MUST NOT explicitly set start timestamp — [L410](references/opentelemetry-specification/v1.55.0/trace/api.md#L410)
- [ ] Implementations MUST provide an option to create a Span as a root span — [L416](references/opentelemetry-specification/v1.55.0/trace/api.md#L416)
- [ ] Implementations MUST generate a new TraceId for each root span created — [L417](references/opentelemetry-specification/v1.55.0/trace/api.md#L417)
- [ ] For a Span with a parent, TraceId MUST be the same as the parent — [L418](references/opentelemetry-specification/v1.55.0/trace/api.md#L418)
- [ ] Child span MUST inherit all TraceState values of its parent by default — [L419](references/opentelemetry-specification/v1.55.0/trace/api.md#L419)
- [ ] Any span that is created MUST also be ended — [L426](references/opentelemetry-specification/v1.55.0/trace/api.md#L426)

### Specifying Links

- [ ] During Span creation, a user MUST have the ability to record links to other Spans — [L444](references/opentelemetry-specification/v1.55.0/trace/api.md#L444)

### Span Operations — Get Context

- [ ] Span interface MUST provide an API that returns the SpanContext for the given Span — [L457](references/opentelemetry-specification/v1.55.0/trace/api.md#L457)
- [ ] Returned SpanContext value MUST be the same for the entire Span lifetime — [L460](references/opentelemetry-specification/v1.55.0/trace/api.md#L460)

### Span Operations — IsRecording

- [ ] After a Span is ended, IsRecording SHOULD return false — [L478](references/opentelemetry-specification/v1.55.0/trace/api.md#L478)
- [ ] IsRecording SHOULD NOT take any parameters — [L483](references/opentelemetry-specification/v1.55.0/trace/api.md#L483)
- [ ] IsRecording SHOULD be used to avoid expensive computations of Span attributes or events when Span is not recorded — [L485](references/opentelemetry-specification/v1.55.0/trace/api.md#L485)

### Span Operations — Set Attributes

- [ ] Span MUST have the ability to set Attributes — [L497](references/opentelemetry-specification/v1.55.0/trace/api.md#L497)
- [ ] Span interface MUST provide an API to set a single Attribute — [L499](references/opentelemetry-specification/v1.55.0/trace/api.md#L499)
- [ ] Setting an attribute with the same key as an existing attribute SHOULD overwrite the existing attribute's value — [L510](references/opentelemetry-specification/v1.55.0/trace/api.md#L510)

### Span Operations — Add Events

- [ ] Span MUST have the ability to add events — [L522](references/opentelemetry-specification/v1.55.0/trace/api.md#L522)
- [ ] Span interface MUST provide an API to record a single Event — [L533](references/opentelemetry-specification/v1.55.0/trace/api.md#L533)
- [ ] Events SHOULD preserve the order in which they are recorded — [L544](references/opentelemetry-specification/v1.55.0/trace/api.md#L544)

### Span Operations — Add Link

- [ ] Span MUST have the ability to add Links after its creation — [L562](references/opentelemetry-specification/v1.55.0/trace/api.md#L562)

### Span Operations — Set Status

- [ ] Description MUST only be used with the Error StatusCode value — [L574](references/opentelemetry-specification/v1.55.0/trace/api.md#L574)
- [ ] Span interface MUST provide an API to set the Status — [L594](references/opentelemetry-specification/v1.55.0/trace/api.md#L594)
- [ ] Description MUST be IGNORED for StatusCode Ok & Unset values — [L599](references/opentelemetry-specification/v1.55.0/trace/api.md#L599)
- [ ] Status code SHOULD remain unset except in specific circumstances — [L602](references/opentelemetry-specification/v1.55.0/trace/api.md#L602)
- [ ] Attempt to set value Unset SHOULD be ignored — [L603](references/opentelemetry-specification/v1.55.0/trace/api.md#L603)
- [ ] When status is set to Error by instrumentation libraries, the Description SHOULD be documented and predictable — [L606](references/opentelemetry-specification/v1.55.0/trace/api.md#L606)
- [ ] Instrumentation Libraries SHOULD publish their own conventions for status descriptions not covered by semantic conventions — [L609](references/opentelemetry-specification/v1.55.0/trace/api.md#L609)
- [ ] Instrumentation Libraries SHOULD NOT set status code to Ok unless explicitly configured to do so — [L613](references/opentelemetry-specification/v1.55.0/trace/api.md#L613)
- [ ] Instrumentation Libraries SHOULD leave status code as Unset unless there is an error — [L614](references/opentelemetry-specification/v1.55.0/trace/api.md#L614)
- [ ] When span status is set to Ok it SHOULD be considered final and any further attempts to change it SHOULD be ignored — [L619](references/opentelemetry-specification/v1.55.0/trace/api.md#L619)
- [ ] Analysis tools SHOULD respond to an Ok status by suppressing any errors they would otherwise generate — [L622](references/opentelemetry-specification/v1.55.0/trace/api.md#L622)

### Span Operations — End

- [ ] Implementations SHOULD ignore all subsequent calls to End and any other Span methods after Span is finished — [L652](references/opentelemetry-specification/v1.55.0/trace/api.md#L652)
- [ ] All API implementations of language-specific end methods MUST internally call the End method — [L659](references/opentelemetry-specification/v1.55.0/trace/api.md#L659)
- [ ] End MUST NOT have any effects on child spans — [L662](references/opentelemetry-specification/v1.55.0/trace/api.md#L662)
- [ ] End MUST NOT inactivate the Span in any Context it is active in — [L665](references/opentelemetry-specification/v1.55.0/trace/api.md#L665)
- [ ] It MUST still be possible to use an ended span as parent via a Context it is contained in — [L666](references/opentelemetry-specification/v1.55.0/trace/api.md#L666)
- [ ] If end timestamp is omitted, this MUST be treated equivalent to passing the current time — [L673](references/opentelemetry-specification/v1.55.0/trace/api.md#L673)
- [ ] End operation itself MUST NOT perform blocking I/O on the calling thread — [L677](references/opentelemetry-specification/v1.55.0/trace/api.md#L677)
- [ ] Any locking used SHOULD be minimized and SHOULD be removed entirely if possible — [L678](references/opentelemetry-specification/v1.55.0/trace/api.md#L678)

### Span Operations — Record Exception

- [ ] Languages SHOULD provide a RecordException method if the language uses exceptions — [L686](references/opentelemetry-specification/v1.55.0/trace/api.md#L686)
- [ ] RecordException MUST record an exception as an Event with the conventions outlined in the exceptions document — [L693](references/opentelemetry-specification/v1.55.0/trace/api.md#L693)
- [ ] The minimum required argument SHOULD be no more than only an exception object — [L695](references/opentelemetry-specification/v1.55.0/trace/api.md#L695)
- [ ] If RecordException is provided, the method MUST accept an optional parameter to provide additional event attributes — [L697](references/opentelemetry-specification/v1.55.0/trace/api.md#L697)
- [ ] Additional event attributes SHOULD be done in the same way as for the AddEvent method — [L699](references/opentelemetry-specification/v1.55.0/trace/api.md#L699)

### Span Lifetime

- [ ] Start and end time as well as Event's timestamps MUST be recorded at a time of calling of corresponding API — [L715](references/opentelemetry-specification/v1.55.0/trace/api.md#L715)

### Wrapping a SpanContext in a Span

- [ ] API MUST provide an operation for wrapping a SpanContext with an object implementing the Span interface — [L720](references/opentelemetry-specification/v1.55.0/trace/api.md#L720)
- [ ] If a new type is required, it SHOULD NOT be exposed publicly if possible — [L724](references/opentelemetry-specification/v1.55.0/trace/api.md#L724)
- [ ] If a new type must be publicly exposed, it SHOULD be named NonRecordingSpan — [L727](references/opentelemetry-specification/v1.55.0/trace/api.md#L727)
- [ ] GetContext MUST return the wrapped SpanContext — [L731](references/opentelemetry-specification/v1.55.0/trace/api.md#L731)
- [ ] IsRecording MUST return false — [L732](references/opentelemetry-specification/v1.55.0/trace/api.md#L732)
- [ ] The remaining functionality of Span MUST be defined as no-op operations — [L735](references/opentelemetry-specification/v1.55.0/trace/api.md#L735)
- [ ] Wrapping functionality MUST be fully implemented in the API — [L739](references/opentelemetry-specification/v1.55.0/trace/api.md#L739)
- [ ] Wrapping functionality SHOULD NOT be overridable — [L739](references/opentelemetry-specification/v1.55.0/trace/api.md#L739)

### Link

- [ ] A user MUST have the ability to record links to other SpanContexts — [L805](references/opentelemetry-specification/v1.55.0/trace/api.md#L805)
- [ ] API MUST provide an API to record a single Link — [L815](references/opentelemetry-specification/v1.55.0/trace/api.md#L815)
- [ ] Implementations SHOULD record links containing SpanContext with empty TraceId or SpanId as long as either attribute set or TraceState is non-empty — [L821](references/opentelemetry-specification/v1.55.0/trace/api.md#L821)
- [ ] Span SHOULD preserve the order in which Links are set — [L830](references/opentelemetry-specification/v1.55.0/trace/api.md#L830)
- [ ] API documentation MUST state that adding links at span creation is preferred to calling AddLink later — [L832](references/opentelemetry-specification/v1.55.0/trace/api.md#L832)

### Concurrency Requirements

- [ ] TracerProvider — all methods MUST be safe for concurrent use — [L842](references/opentelemetry-specification/v1.55.0/trace/api.md#L842)
- [ ] Tracer — all methods MUST be safe for concurrent use — [L845](references/opentelemetry-specification/v1.55.0/trace/api.md#L845)
- [ ] Span — all methods MUST be safe for concurrent use — [L848](references/opentelemetry-specification/v1.55.0/trace/api.md#L848)
- [ ] Event — Events are immutable and MUST be safe for concurrent use — [L851](references/opentelemetry-specification/v1.55.0/trace/api.md#L851)
- [ ] Link — Links are immutable and SHOULD be safe for concurrent use — [L853](references/opentelemetry-specification/v1.55.0/trace/api.md#L853)

### Behavior of the API in the absence of an installed SDK

- [ ] API MUST return a non-recording Span with the SpanContext in the parent Context — [L865](references/opentelemetry-specification/v1.55.0/trace/api.md#L865)
- [ ] If the Span in the parent Context is already non-recording, it SHOULD be returned directly without instantiating a new Span — [L867](references/opentelemetry-specification/v1.55.0/trace/api.md#L867)
- [ ] If parent Context contains no Span, an empty non-recording Span MUST be returned (all-zero Span and Trace IDs, empty Tracestate, unsampled TraceFlags) — [L869](references/opentelemetry-specification/v1.55.0/trace/api.md#L869)

## Trace SDK

> Ref: [trace/sdk.md](references/opentelemetry-specification/v1.55.0/trace/sdk.md)

### TracerProvider — Tracer Creation

- [ ] It SHOULD only be possible to create Tracer instances through a TracerProvider — [L95](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L95)
- [ ] TracerProvider MUST implement the Get a Tracer API — [L98](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L98)
- [ ] The input provided by the user MUST be used to create an InstrumentationScope instance stored on the created Tracer — [L100](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L100)

### TracerProvider — Configuration

- [ ] Configuration (SpanProcessors, IdGenerator, SpanLimits, Sampler) MUST be owned by the TracerProvider — [L111](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L111)
- [ ] If configuration is updated, it MUST also apply to all already returned Tracers — [L119](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L119)
- [ ] Updated configuration MUST NOT matter whether a Tracer was obtained before or after the configuration change — [L120](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L120)

### TracerProvider — Shutdown

- [ ] Shutdown MUST be called only once for each TracerProvider instance — [L161](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L161)
- [ ] After Shutdown, SDKs SHOULD return a valid no-op Tracer for subsequent get Tracer calls — [L163](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L163)
- [ ] Shutdown SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L165](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L165)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L168](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L168)
- [ ] Shutdown MUST be implemented at least by invoking Shutdown within all internal processors — [L173](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L173)

### TracerProvider — ForceFlush

- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L179](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L179)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L182](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L182)
- [ ] ForceFlush MUST invoke ForceFlush on all registered SpanProcessors — [L187](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L187)

### Additional Span Interfaces

- [ ] Readable span: a function receiving this MUST be able to access all information added to the span — [L242](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L242)
- [ ] Readable span: MUST be able to access InstrumentationScope and Resource information associated with the span — [L249](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L249)
- [ ] Readable span: MUST also be able to access InstrumentationLibrary (deprecated) with same name and version as InstrumentationScope — [L251](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L251)
- [ ] Readable span: MUST be able to reliably determine whether the Span has ended — [L255](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L255)
- [ ] Readable span: counts for dropped attributes, events and links MUST be available for exporters — [L260](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L260)
- [ ] Readable span: implementations MUST expose at least the full parent SpanContext — [L266](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L266)
- [ ] Read/write span: It MUST be possible to obtain the same Span instance and type that the span creation API returned — [L283](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L283)

### Sampling

- [ ] Span Processor MUST receive only spans which have IsRecording set to true — [L304](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L304)
- [ ] Span Exporter SHOULD NOT receive spans unless the Sampled flag was also set — [L305](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L305)
- [ ] Span Exporters MUST receive spans which have Sampled flag set to true — [L310](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L310)
- [ ] Span Exporters SHOULD NOT receive spans that do not have Sampled flag set — [L311](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L311)
- [ ] SDK MUST NOT allow the combination SampledFlag == true and IsRecording == false — [L320](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L320)

### SDK Span Creation

- [ ] When asked to create a Span, SDK MUST act as if doing the following in order (use valid parent trace ID or generate new, query Sampler, generate new span ID, create span per decision) — [L339](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L339)

### Sampler — ShouldSample

- [ ] If parent SpanContext contains a valid TraceId, they MUST always match — [L380](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L380)
- [ ] RECORD_ONLY decision: Sampled flag MUST NOT be set — [L398](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L398)
- [ ] RECORD_AND_SAMPLE decision: Sampled flag MUST be set — [L399](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L399)
- [ ] Samplers SHOULD normally return the passed-in Tracestate if they do not intend to change it — [L405](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L405)

### Sampler — GetDescription

- [ ] Callers SHOULD NOT cache the returned value of GetDescription — [L416](references/opentelemetry-specification-
Now I have all the data I need. Let me compile the complete checklist.

## Trace API

> Ref: [trace/api.md](references/opentelemetry-specification/v1.55.0/trace/api.md)

### TracerProvider

- [ ] API SHOULD provide a way to set/register and access a global default TracerProvider — [L96](references/opentelemetry-specification/v1.55.0/trace/api.md#L96)
- [ ] Implementations of TracerProvider SHOULD allow creating an arbitrary number of TracerProvider instances — [L104](references/opentelemetry-specification/v1.55.0/trace/api.md#L104)
- [ ] TracerProvider MUST provide the Get a Tracer function — [L109](references/opentelemetry-specification/v1.55.0/trace/api.md#L109)

### Get a Tracer

- [ ] Get a Tracer API MUST accept `name` and optional `version`, `schema_url`, `attributes` parameters — [L115](references/opentelemetry-specification/v1.55.0/trace/api.md#L115)
- [ ] `name` SHOULD uniquely identify the instrumentation scope — [L117](references/opentelemetry-specification/v1.55.0/trace/api.md#L117)
- [ ] If invalid name is specified, a working Tracer MUST be returned as fallback (not null or exception) — [L126](references/opentelemetry-specification/v1.55.0/trace/api.md#L126)
- [ ] If invalid name, Tracer's `name` property SHOULD be set to empty string — [L128](references/opentelemetry-specification/v1.55.0/trace/api.md#L128)
- [ ] If invalid name, a message reporting invalid value SHOULD be logged — [L129](references/opentelemetry-specification/v1.55.0/trace/api.md#L129)
- [ ] Implementations MUST NOT require users to repeatedly obtain a Tracer with the same identity to pick up configuration changes — [L146](references/opentelemetry-specification/v1.55.0/trace/api.md#L146)

### Context Interaction

- [ ] API MUST provide functionality to extract the Span from a Context instance — [L164](references/opentelemetry-specification/v1.55.0/trace/api.md#L164)
- [ ] API MUST provide functionality to combine the Span with a Context instance, creating a new Context — [L164](references/opentelemetry-specification/v1.55.0/trace/api.md#L164)
- [ ] API users SHOULD NOT have access to the Context Key used by the Tracing API implementation — [L170](references/opentelemetry-specification/v1.55.0/trace/api.md#L170)
- [ ] If implicit Context propagation is supported, API SHOULD provide get currently active span and set active span functionality — [L174](references/opentelemetry-specification/v1.55.0/trace/api.md#L174)
- [ ] Context interaction functionality SHOULD be fully implemented in the API when possible — [L182](references/opentelemetry-specification/v1.55.0/trace/api.md#L182)

### Tracer

- [ ] Tracer MUST provide function to create a new Span — [L193](references/opentelemetry-specification/v1.55.0/trace/api.md#L193)
- [ ] Tracer SHOULD provide function to report if Tracer is Enabled — [L197](references/opentelemetry-specification/v1.55.0/trace/api.md#L197)

### SpanContext

- [ ] API MUST implement methods to create a SpanContext; these SHOULD be the only way to create one — [L252](references/opentelemetry-specification/v1.55.0/trace/api.md#L252)
- [ ] SpanContext creation MUST be fully implemented in the API, and SHOULD NOT be overridable — [L253](references/opentelemetry-specification/v1.55.0/trace/api.md#L253)
- [ ] API MUST allow retrieving TraceId and SpanId in Hex form (32-hex lowercase for TraceId, 16-hex lowercase for SpanId) — [L258](references/opentelemetry-specification/v1.55.0/trace/api.md#L258)
- [ ] API MUST allow retrieving TraceId and SpanId in Binary form (16-byte array for TraceId, 8-byte array for SpanId) — [L263](references/opentelemetry-specification/v1.55.0/trace/api.md#L263)
- [ ] API SHOULD NOT expose details about how TraceId/SpanId are internally stored — [L266](references/opentelemetry-specification/v1.55.0/trace/api.md#L266)
- [ ] IsValid API MUST be provided, returning true if SpanContext has non-zero TraceID and non-zero SpanID — [L271](references/opentelemetry-specification/v1.55.0/trace/api.md#L271)
- [ ] IsRemote API MUST be provided, returning true if SpanContext was propagated from a remote parent — [L275](references/opentelemetry-specification/v1.55.0/trace/api.md#L275)
- [ ] When extracting SpanContext through Propagators API, IsRemote MUST return true — [L278](references/opentelemetry-specification/v1.55.0/trace/api.md#L278)
- [ ] For SpanContext of any child spans, IsRemote MUST return false — [L278](references/opentelemetry-specification/v1.55.0/trace/api.md#L278)

### TraceState

- [ ] Tracing API MUST provide at least: get value, add key/value, update value, delete key/value on TraceState — [L284](references/opentelemetry-specification/v1.55.0/trace/api.md#L284)
- [ ] TraceState operations MUST follow the rules in W3C Trace Context specification — [L291](references/opentelemetry-specification/v1.55.0/trace/api.md#L291)
- [ ] All mutating operations MUST return a new TraceState with modifications applied — [L292](references/opentelemetry-specification/v1.55.0/trace/api.md#L292)
- [ ] TraceState MUST at all times be valid according to W3C Trace Context specification — [L293](references/opentelemetry-specification/v1.55.0/trace/api.md#L293)
- [ ] Every mutating operation MUST validate input parameters — [L294](references/opentelemetry-specification/v1.55.0/trace/api.md#L294)
- [ ] If invalid value is passed, operation MUST NOT return TraceState containing invalid data and MUST follow general error handling guidelines — [L295](references/opentelemetry-specification/v1.55.0/trace/api.md#L295)

### Span

- [ ] Span name SHOULD be the most general string identifying a class of Spans, still human-readable — [L329](references/opentelemetry-specification/v1.55.0/trace/api.md#L329)
- [ ] Generality SHOULD be prioritized over human-readability — [L333](references/opentelemetry-specification/v1.55.0/trace/api.md#L333)
- [ ] Span's start time SHOULD be set to current time on span creation — [L365](references/opentelemetry-specification/v1.55.0/trace/api.md#L365)
- [ ] After span creation, it SHOULD be possible to change its name, set Attributes, add Events, and set Status — [L366](references/opentelemetry-specification/v1.55.0/trace/api.md#L366)
- [ ] Name, Attributes, Events, Status MUST NOT be changed after the Span's end time has been set — [L368](references/opentelemetry-specification/v1.55.0/trace/api.md#L368)
- [ ] Implementations SHOULD NOT provide access to a Span's attributes besides its SpanContext — [L371](references/opentelemetry-specification/v1.55.0/trace/api.md#L371)
- [ ] Alternative implementations MUST NOT allow callers to create Spans directly; all Spans MUST be created via a Tracer — [L375](references/opentelemetry-specification/v1.55.0/trace/api.md#L375)

### Span Creation

- [ ] There MUST NOT be any API for creating a Span other than with a Tracer — [L380](references/opentelemetry-specification/v1.55.0/trace/api.md#L380)
- [ ] In languages with implicit Context propagation, Span creation MUST NOT set the new Span as active in current Context by default — [L382](references/opentelemetry-specification/v1.55.0/trace/api.md#L382)
- [ ] Span creation API MUST accept span name, parent Context, SpanKind, Attributes, Links, Start timestamp — [L387](references/opentelemetry-specification/v1.55.0/trace/api.md#L387)
- [ ] Span creation API MUST NOT accept a Span or SpanContext as parent, only a full Context — [L393](references/opentelemetry-specification/v1.55.0/trace/api.md#L393)
- [ ] Semantic parent of the Span MUST be determined according to Determining the Parent Span from a Context rules — [L395](references/opentelemetry-specification/v1.55.0/trace/api.md#L395)
- [ ] API documentation MUST state that adding attributes at span creation is preferred to calling SetAttribute later — [L403](references/opentelemetry-specification/v1.55.0/trace/api.md#L403)
- [ ] Implementations MUST provide an option to create a Span as a root span — [L416](references/opentelemetry-specification/v1.55.0/trace/api.md#L416)
- [ ] Implementations MUST generate a new TraceId for each root span created — [L417](references/opentelemetry-specification/v1.55.0/trace/api.md#L417)
- [ ] For a Span with a parent, the TraceId MUST be the same as the parent — [L418](references/opentelemetry-specification/v1.55.0/trace/api.md#L418)
- [ ] Child span MUST inherit all TraceState values of its parent by default — [L419](references/opentelemetry-specification/v1.55.0/trace/api.md#L419)
- [ ] Any span that is created MUST also be ended — [L426](references/opentelemetry-specification/v1.55.0/trace/api.md#L426)

### Specifying Links

- [ ] During Span creation, user MUST have the ability to record links to other Spans — [L444](references/opentelemetry-specification/v1.55.0/trace/api.md#L444)

### Span Operations — Get Context

- [ ] Span interface MUST provide an API that returns the SpanContext for the given Span — [L457](references/opentelemetry-specification/v1.55.0/trace/api.md#L457)
- [ ] Returned SpanContext value MUST be the same for the entire Span lifetime — [L460](references/opentelemetry-specification/v1.55.0/trace/api.md#L460)

### Span Operations — IsRecording

- [ ] After a Span is ended, it SHOULD become non-recording and IsRecording SHOULD return false — [L478](references/opentelemetry-specification/v1.55.0/trace/api.md#L478)
- [ ] IsRecording SHOULD NOT take any parameters — [L483](references/opentelemetry-specification/v1.55.0/trace/api.md#L483)
- [ ] IsRecording SHOULD be used to avoid expensive computations when a Span is not recorded — [L485](references/opentelemetry-specification/v1.55.0/trace/api.md#L485)

### Span Operations — Set Attributes

- [ ] Span MUST have the ability to set Attributes — [L497](references/opentelemetry-specification/v1.55.0/trace/api.md#L497)
- [ ] Span interface MUST provide an API to set a single Attribute — [L499](references/opentelemetry-specification/v1.55.0/trace/api.md#L499)
- [ ] Setting an attribute with the same key as existing SHOULD overwrite the existing value — [L510](references/opentelemetry-specification/v1.55.0/trace/api.md#L510)

### Span Operations — Add Events

- [ ] Span MUST have the ability to add events — [L522](references/opentelemetry-specification/v1.55.0/trace/api.md#L522)
- [ ] Span interface MUST provide an API to record a single Event — [L533](references/opentelemetry-specification/v1.55.0/trace/api.md#L533)
- [ ] Events SHOULD preserve the order in which they are recorded — [L544](references/opentelemetry-specification/v1.55.0/trace/api.md#L544)

### Span Operations — Add Link

- [ ] Span MUST have the ability to add Links after creation — [L562](references/opentelemetry-specification/v1.55.0/trace/api.md#L562)

### Span Operations — Set Status

- [ ] Description MUST only be used with the Error StatusCode value — [L574](references/opentelemetry-specification/v1.55.0/trace/api.md#L574)
- [ ] Span interface MUST provide an API to set the Status (SetStatus) — [L594](references/opentelemetry-specification/v1.55.0/trace/api.md#L594)
- [ ] Description MUST be IGNORED for StatusCode Ok & Unset values — [L599](references/opentelemetry-specification/v1.55.0/trace/api.md#L599)
- [ ] Status code SHOULD remain unset except for documented circumstances — [L602](references/opentelemetry-specification/v1.55.0/trace/api.md#L602)
- [ ] Attempt to set value Unset SHOULD be ignored — [L603](references/opentelemetry-specification/v1.55.0/trace/api.md#L603)
- [ ] When status is set to Ok, it SHOULD be considered final and further attempts to change it SHOULD be ignored — [L619](references/opentelemetry-specification/v1.55.0/trace/api.md#L619)

### Span Operations — End

- [ ] Implementations SHOULD ignore all subsequent calls to End and any other Span methods after Span is finished — [L652](references/opentelemetry-specification/v1.55.0/trace/api.md#L652)
- [ ] All API implementations of end-like methods MUST internally call End and be documented to do so — [L659](references/opentelemetry-specification/v1.55.0/trace/api.md#L659)
- [ ] End MUST NOT have any effects on child spans — [L662](references/opentelemetry-specification/v1.55.0/trace/api.md#L662)
- [ ] End MUST NOT inactivate the Span in any Context it is active in — [L665](references/opentelemetry-specification/v1.55.0/trace/api.md#L665)
- [ ] It MUST still be possible to use an ended span as parent via a Context it is contained in — [L666](references/opentelemetry-specification/v1.55.0/trace/api.md#L666)
- [ ] If end timestamp is omitted, this MUST be treated equivalent to passing the current time — [L673](references/opentelemetry-specification/v1.55.0/trace/api.md#L673)
- [ ] End operation itself MUST NOT perform blocking I/O on the calling thread — [L677](references/opentelemetry-specification/v1.55.0/trace/api.md#L677)
- [ ] Any locking used SHOULD be minimized and SHOULD be removed entirely if possible — [L678](references/opentelemetry-specification/v1.55.0/trace/api.md#L678)

### Span Operations — Record Exception

- [ ] Languages SHOULD provide a RecordException method if the language uses exceptions — [L686](references/opentelemetry-specification/v1.55.0/trace/api.md#L686)
- [ ] RecordException MUST record an exception as an Event with the conventions outlined in the exceptions document — [L693](references/opentelemetry-specification/v1.55.0/trace/api.md#L693)
- [ ] Minimum required argument SHOULD be no more than only an exception object — [L695](references/opentelemetry-specification/v1.55.0/trace/api.md#L695)
- [ ] If RecordException is provided, it MUST accept an optional parameter for additional event attributes — [L697](references/opentelemetry-specification/v1.55.0/trace/api.md#L697)
- [ ] Additional attributes SHOULD be done in the same way as for AddEvent — [L699](references/opentelemetry-specification/v1.55.0/trace/api.md#L699)

### Span Lifetime

- [ ] Start/end time and Event timestamps MUST be recorded at the time of calling the corresponding API — [L715](references/opentelemetry-specification/v1.55.0/trace/api.md#L715)

### Wrapping a SpanContext in a Span

- [ ] API MUST provide an operation for wrapping a SpanContext with an object implementing the Span interface — [L720](references/opentelemetry-specification/v1.55.0/trace/api.md#L720)
- [ ] If a new type is required, it SHOULD NOT be exposed publicly if possible — [L724](references/opentelemetry-specification/v1.55.0/trace/api.md#L724)
- [ ] If new type must be publicly exposed, it SHOULD be named NonRecordingSpan — [L727](references/opentelemetry-specification/v1.55.0/trace/api.md#L727)
- [ ] GetContext MUST return the wrapped SpanContext — [L731](references/opentelemetry-specification/v1.55.0/trace/api.md#L731)
- [ ] IsRecording MUST return false — [L732](references/opentelemetry-specification/v1.55.0/trace/api.md#L732)
- [ ] Remaining functionality of Span MUST be defined as no-op operations — [L735](references/opentelemetry-specification/v1.55.0/trace/api.md#L735)
- [ ] This functionality MUST be fully implemented in the API, and SHOULD NOT be overridable — [L739](references/opentelemetry-specification/v1.55.0/trace/api.md#L739)

### Link

- [ ] User MUST have the ability to record links to other SpanContexts — [L805](references/opentelemetry-specification/v1.55.0/trace/api.md#L805)
- [ ] API MUST provide an API to record a single Link — [L815](references/opentelemetry-specification/v1.55.0/trace/api.md#L815)
- [ ] Implementations SHOULD record links containing SpanContext with empty TraceId or SpanId as long as attribute set or TraceState is non-empty — [L821](references/opentelemetry-specification/v1.55.0/trace/api.md#L821)
- [ ] Span SHOULD preserve the order in which Links are set — [L830](references/opentelemetry-specification/v1.55.0/trace/api.md#L830)
- [ ] API documentation MUST state that adding links at span creation is preferred to calling AddLink later — [L832](references/opentelemetry-specification/v1.55.0/trace/api.md#L832)

### Concurrency Requirements

- [ ] TracerProvider — all methods MUST be safe for concurrent use — [L842](references/opentelemetry-specification/v1.55.0/trace/api.md#L842)
- [ ] Tracer — all methods MUST be safe for concurrent use — [L845](references/opentelemetry-specification/v1.55.0/trace/api.md#L845)
- [ ] Span — all methods MUST be safe for concurrent use — [L848](references/opentelemetry-specification/v1.55.0/trace/api.md#L848)
- [ ] Event — Events are immutable and MUST be safe for concurrent use — [L851](references/opentelemetry-specification/v1.55.0/trace/api.md#L851)
- [ ] Link — Links are immutable and SHOULD be safe for concurrent use — [L853](references/opentelemetry-specification/v1.55.0/trace/api.md#L853)

### Behavior of the API in the absence of an installed SDK

- [ ] API MUST return a non-recording Span with the SpanContext in the parent Context — [L865](references/opentelemetry-specification/v1.55.0/trace/api.md#L865)
- [ ] If the Span in parent Context is already non-recording, it SHOULD be returned directly without instantiating a new Span — [L867](references/opentelemetry-specification/v1.55.0/trace/api.md#L867)
- [ ] If the parent Context contains no Span, an empty non-recording Span MUST be returned (all-zero IDs, empty Tracestate, unsampled TraceFlags) — [L869](references/opentelemetry-specification/v1.55.0/trace/api.md#L869)

## Trace SDK

> Ref: [trace/sdk.md](references/opentelemetry-specification/v1.55.0/trace/sdk.md)

### TracerProvider — Tracer Creation

- [ ] It SHOULD only be possible to create Tracer instances through a TracerProvider — [L95](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L95)
- [ ] TracerProvider MUST implement the Get a Tracer API — [L98](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L98)
- [ ] Input provided by the user MUST be used to create an InstrumentationScope instance stored on the created Tracer — [L100](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L100)

### TracerProvider — Configuration

- [ ] Configuration (SpanProcessors, IdGenerator, SpanLimits, Sampler) MUST be owned by the TracerProvider — [L113](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L113)
- [ ] If configuration is updated, the updated configuration MUST also apply to all already returned Tracers — [L119](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L119)
- [ ] Updated configuration MUST NOT matter whether a Tracer was obtained before or after the configuration change — [L120](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L120)

### TracerProvider — Shutdown

- [ ] Shutdown MUST be called only once for each TracerProvider instance — [L161](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L161)
- [ ] After Shutdown, SDKs SHOULD return a valid no-op Tracer for subsequent get-Tracer calls — [L163](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L163)
- [ ] Shutdown SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L165](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L165)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L168](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L168)
- [ ] Shutdown MUST be implemented at least by invoking Shutdown within all internal processors — [L173](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L173)

### TracerProvider — ForceFlush

- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L179](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L179)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L182](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L182)
- [ ] ForceFlush MUST invoke ForceFlush on all registered SpanProcessors — [L187](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L187)

### Additional Span Interfaces

- [ ] Readable span: function receiving it MUST be able to access all information added to the span — [L242](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L242)
- [ ] Readable span: function MUST be able to access InstrumentationScope and Resource information — [L249](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L249)
- [ ] Readable span: function MUST also be able to access InstrumentationLibrary (deprecated) with same name and version — [L251](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L251)
- [ ] Readable span: function MUST be able to reliably determine whether the Span has ended — [L255](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L255)
- [ ] Counts for dropped attributes, events, and links MUST be available for exporters to report — [L260](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L260)
- [ ] Implementations MUST expose at least the full parent SpanContext — [L266](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L266)
- [ ] Read/write span: it MUST be possible to obtain the same Span instance and type that span creation API returned — [L283](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L283)

### Sampling

- [ ] Span Processor MUST receive only spans where IsRecording is true — [L304](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L304)
- [ ] Span Exporter SHOULD NOT receive spans unless the Sampled flag was also set — [L305](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L305)
- [ ] Span Exporters MUST receive spans with Sampled flag set to true — [L310](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L310)
- [ ] Span Exporters SHOULD NOT receive spans without the Sampled flag set — [L311](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L311)
- [ ] SDK MUST NOT allow the combination SampledFlag == true and IsRecording == false — [L320](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L320)

### SDK Span Creation

- [ ] When asked to create a Span, SDK MUST act as if doing the following in order: use valid parent trace ID or generate new, query Sampler, generate new span ID, create span based on decision — [L339](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L339)

### Sampler — ShouldSample

- [ ] If parent SpanContext contains valid TraceId, they MUST always match — [L380](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L380)
- [ ] RECORD_ONLY decision: Sampled flag MUST NOT be set — [L398](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L398)
- [ ] RECORD_AND_SAMPLE decision: Sampled flag MUST be set — [L399](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L399)
- [ ] Samplers SHOULD normally return the passed-in Tracestate if they do not intend to change it — [L405](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L405)

### Sampler — GetDescription

- [ ] Callers SHOULD NOT cache the returned value of GetDescription — [L416](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L416)

### Built-in Samplers — AlwaysOn

- [ ] AlwaysOn description MUST be `AlwaysOnSampler` — [L426](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L426)

### Built-in Samplers — AlwaysOff

- [ ] AlwaysOff description MUST be `AlwaysOffSampler` — [L431](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L431)

### Built-in Samplers — TraceIdRatioBased

- [ ] TraceIdRatioBased MUST ignore the parent SampledFlag — [L447](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L447)
- [ ] TraceIdRatioBased description MUST return a string of the form `"TraceIdRatioBased{RATIO}"` — [L450](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L450)
- [ ] Precision of the ratio SHOULD be high enough to identify different ratios — [L453](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L453)
- [ ] Sampling algorithm MUST be deterministic (deterministic hash of TraceId) — [L462](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L462)
- [ ] TraceIdRatioBased with given probability MUST also sample all traces that lower probability sampler would sample — [L467](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L467)

### Span Limits

- [ ] Span attributes MUST adhere to the common rules of attribute limits — [L836](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L836)
- [ ] If SDK implements limits, it MUST provide a way to change these limits via TracerProvider configuration — [L841](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L841)
- [ ] Name of config options SHOULD be EventCountLimit and LinkCountLimit — [L845](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L845)
- [ ] Options class SHOULD be called SpanLimits — [L846](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L846)
- [ ] There SHOULD be a log message when an attribute, event, or link is discarded due to limits — [L873](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L873)
- [ ] Discard
Now I have all the data needed. Let me compile the complete checklist.

## Trace API

> Ref: [trace/api.md](references/opentelemetry-specification/v1.55.0/trace/api.md)

### TracerProvider

- [ ] API SHOULD provide a way to set/register and access a global default TracerProvider — [L96](references/opentelemetry-specification/v1.55.0/trace/api.md#L96)
- [ ] Implementations of TracerProvider SHOULD allow creating an arbitrary number of TracerProvider instances — [L104](references/opentelemetry-specification/v1.55.0/trace/api.md#L104)
- [ ] TracerProvider MUST provide the Get a Tracer function — [L109](references/opentelemetry-specification/v1.55.0/trace/api.md#L109)

### Get a Tracer

- [ ] Get a Tracer API MUST accept `name`, `version`, `schema_url`, and `attributes` parameters — [L115](references/opentelemetry-specification/v1.55.0/trace/api.md#L115)
- [ ] `name` SHOULD uniquely identify the instrumentation scope — [L117](references/opentelemetry-specification/v1.55.0/trace/api.md#L117)
- [ ] If invalid name is specified, a working Tracer MUST be returned as a fallback — [L126](references/opentelemetry-specification/v1.55.0/trace/api.md#L126)
- [ ] Fallback Tracer's `name` property SHOULD be set to an empty string — [L128](references/opentelemetry-specification/v1.55.0/trace/api.md#L128)
- [ ] A message reporting that the specified value is invalid SHOULD be logged — [L129](references/opentelemetry-specification/v1.55.0/trace/api.md#L129)
- [ ] Implementations MUST NOT require users to repeatedly obtain a Tracer with the same identity to pick up configuration changes — [L146](references/opentelemetry-specification/v1.55.0/trace/api.md#L146)

### Context Interaction

- [ ] API MUST provide functionality to extract the Span from a Context instance — [L164](references/opentelemetry-specification/v1.55.0/trace/api.md#L164)
- [ ] API MUST provide functionality to combine the Span with a Context instance — [L164](references/opentelemetry-specification/v1.55.0/trace/api.md#L164)
- [ ] API users SHOULD NOT have access to the Context Key used by the Tracing API implementation — [L170](references/opentelemetry-specification/v1.55.0/trace/api.md#L170)
- [ ] If language supports implicit Context, the API SHOULD provide get/set currently active span — [L174](references/opentelemetry-specification/v1.55.0/trace/api.md#L174)
- [ ] Context interaction functionality SHOULD be fully implemented in the API when possible — [L182](references/opentelemetry-specification/v1.55.0/trace/api.md#L182)

### Tracer

- [ ] Tracer MUST provide function to create a new Span — [L193](references/opentelemetry-specification/v1.55.0/trace/api.md#L193)
- [ ] Tracer SHOULD provide function to report if Tracer is Enabled — [L197](references/opentelemetry-specification/v1.55.0/trace/api.md#L197)

### SpanContext

- [ ] API MUST implement methods to create a SpanContext — [L252](references/opentelemetry-specification/v1.55.0/trace/api.md#L252)
- [ ] SpanContext creation functionality MUST be fully implemented in the API and SHOULD NOT be overridable — [L253](references/opentelemetry-specification/v1.55.0/trace/api.md#L253)
- [ ] API MUST allow retrieving the TraceId and SpanId in Hex and Binary forms — [L258](references/opentelemetry-specification/v1.55.0/trace/api.md#L258)
- [ ] Hex TraceId MUST be a 32-hex-character lowercase string — [L261](references/opentelemetry-specification/v1.55.0/trace/api.md#L261)
- [ ] Hex SpanId MUST be a 16-hex-character lowercase string — [L262](references/opentelemetry-specification/v1.55.0/trace/api.md#L262)
- [ ] Binary TraceId MUST be a 16-byte array — [L263](references/opentelemetry-specification/v1.55.0/trace/api.md#L263)
- [ ] Binary SpanId MUST be an 8-byte array — [L264](references/opentelemetry-specification/v1.55.0/trace/api.md#L264)
- [ ] API SHOULD NOT expose details about how TraceId/SpanId are internally stored — [L266](references/opentelemetry-specification/v1.55.0/trace/api.md#L266)
- [ ] IsValid API MUST be provided, returning true if non-zero TraceID and SpanID — [L271](references/opentelemetry-specification/v1.55.0/trace/api.md#L271)
- [ ] IsRemote API MUST be provided, returning true if SpanContext was propagated from remote parent — [L276](references/opentelemetry-specification/v1.55.0/trace/api.md#L276)
- [ ] When extracting SpanContext through Propagators API, IsRemote MUST return true — [L278](references/opentelemetry-specification/v1.55.0/trace/api.md#L278)
- [ ] For SpanContext of child spans, IsRemote MUST return false — [L278](references/opentelemetry-specification/v1.55.0/trace/api.md#L278)

### TraceState

- [ ] Tracing API MUST provide at least get, add, update, delete operations on TraceState — [L284](references/opentelemetry-specification/v1.55.0/trace/api.md#L284)
- [ ] TraceState operations MUST follow W3C Trace Context specification rules — [L291](references/opentelemetry-specification/v1.55.0/trace/api.md#L291)
- [ ] All mutating operations MUST return a new TraceState with modifications applied — [L292](references/opentelemetry-specification/v1.55.0/trace/api.md#L292)
- [ ] TraceState MUST at all times be valid according to W3C Trace Context specification — [L293](references/opentelemetry-specification/v1.55.0/trace/api.md#L293)
- [ ] Every mutating operation MUST validate input parameters — [L294](references/opentelemetry-specification/v1.55.0/trace/api.md#L294)
- [ ] If invalid value is passed, operation MUST NOT return TraceState containing invalid data and MUST follow general error handling guidelines — [L295](references/opentelemetry-specification/v1.55.0/trace/api.md#L295)

### Span

- [ ] Span name SHOULD be the most general string that identifies a class of Spans — [L329](references/opentelemetry-specification/v1.55.0/trace/api.md#L329)
- [ ] Generality SHOULD be prioritized over human-readability — [L333](references/opentelemetry-specification/v1.55.0/trace/api.md#L333)
- [ ] Span's start time SHOULD be set to current time on span creation — [L365](references/opentelemetry-specification/v1.55.0/trace/api.md#L365)
- [ ] After creation, it SHOULD be possible to change name, set Attributes, add Events, and set Status — [L366](references/opentelemetry-specification/v1.55.0/trace/api.md#L366)
- [ ] Name, Attributes, Events, and Status MUST NOT be changed after Span's end time has been set — [L368](references/opentelemetry-specification/v1.55.0/trace/api.md#L368)
- [ ] Implementations SHOULD NOT provide access to a Span's attributes besides its SpanContext — [L371](references/opentelemetry-specification/v1.55.0/trace/api.md#L371)
- [ ] Alternative implementations MUST NOT allow callers to create Spans directly; all Spans MUST be created via a Tracer — [L375](references/opentelemetry-specification/v1.55.0/trace/api.md#L375)

### Span Creation

- [ ] There MUST NOT be any API for creating a Span other than with a Tracer — [L380](references/opentelemetry-specification/v1.55.0/trace/api.md#L380)
- [ ] Span creation MUST NOT set the newly created Span as active in the current Context by default — [L382](references/opentelemetry-specification/v1.55.0/trace/api.md#L382)
- [ ] The API MUST accept span name, parent Context, SpanKind, Attributes, Links, and Start timestamp — [L387](references/opentelemetry-specification/v1.55.0/trace/api.md#L387)
- [ ] API MUST NOT accept a Span or SpanContext as parent, only a full Context — [L393](references/opentelemetry-specification/v1.55.0/trace/api.md#L393)
- [ ] Semantic parent of the Span MUST be determined according to the rules in Determining the Parent Span from a Context — [L395](references/opentelemetry-specification/v1.55.0/trace/api.md#L395)
- [ ] API documentation MUST state that adding attributes at span creation is preferred to calling SetAttribute later — [L403](references/opentelemetry-specification/v1.55.0/trace/api.md#L403)
- [ ] Start timestamp argument SHOULD only be set when span creation time has already passed — [L408](references/opentelemetry-specification/v1.55.0/trace/api.md#L408)
- [ ] If API is called at moment of logical start, user MUST NOT explicitly set start timestamp — [L410](references/opentelemetry-specification/v1.55.0/trace/api.md#L410)
- [ ] Implementations MUST provide an option to create a Span as a root span — [L416](references/opentelemetry-specification/v1.55.0/trace/api.md#L416)
- [ ] Implementations MUST generate a new TraceId for each root span created — [L417](references/opentelemetry-specification/v1.55.0/trace/api.md#L417)
- [ ] For a Span with a parent, the TraceId MUST be the same as the parent — [L418](references/opentelemetry-specification/v1.55.0/trace/api.md#L418)
- [ ] Child span MUST inherit all TraceState values of its parent by default — [L419](references/opentelemetry-specification/v1.55.0/trace/api.md#L419)
- [ ] During Span creation, user MUST have the ability to record links to other Spans — [L444](references/opentelemetry-specification/v1.55.0/trace/api.md#L444)

### Span Operations — Get Context

- [ ] Span interface MUST provide an API that returns the SpanContext for the given Span — [L457](references/opentelemetry-specification/v1.55.0/trace/api.md#L457)
- [ ] Returned SpanContext value MUST be the same for the entire Span lifetime — [L460](references/opentelemetry-specification/v1.55.0/trace/api.md#L460)

### Span Operations — IsRecording

- [ ] After a Span is ended, it SHOULD become non-recording and IsRecording SHOULD return false — [L478](references/opentelemetry-specification/v1.55.0/trace/api.md#L478)
- [ ] IsRecording SHOULD NOT take any parameters — [L483](references/opentelemetry-specification/v1.55.0/trace/api.md#L483)
- [ ] IsRecording SHOULD be used to avoid expensive computations when Span is not recorded — [L485](references/opentelemetry-specification/v1.55.0/trace/api.md#L485)

### Span Operations — Set Attributes

- [ ] A Span MUST have the ability to set Attributes associated with it — [L497](references/opentelemetry-specification/v1.55.0/trace/api.md#L497)
- [ ] Span interface MUST provide an API to set a single Attribute — [L499](references/opentelemetry-specification/v1.55.0/trace/api.md#L499)
- [ ] Setting an attribute with the same key as an existing attribute SHOULD overwrite the existing value — [L510](references/opentelemetry-specification/v1.55.0/trace/api.md#L510)

### Span Operations — Add Events

- [ ] A Span MUST have the ability to add events — [L522](references/opentelemetry-specification/v1.55.0/trace/api.md#L522)
- [ ] Span interface MUST provide an API to record a single Event — [L533](references/opentelemetry-specification/v1.55.0/trace/api.md#L533)
- [ ] Events SHOULD preserve the order in which they are recorded — [L544](references/opentelemetry-specification/v1.55.0/trace/api.md#L544)

### Span Operations — Add Link

- [ ] A Span MUST have the ability to add Links after creation — [L562](references/opentelemetry-specification/v1.55.0/trace/api.md#L562)

### Span Operations — Set Status

- [ ] Description MUST only be used with the Error StatusCode value — [L574](references/opentelemetry-specification/v1.55.0/trace/api.md#L574)
- [ ] Span interface MUST provide an API to set the Status — [L594](references/opentelemetry-specification/v1.55.0/trace/api.md#L594)
- [ ] Description MUST be IGNORED for StatusCode Ok and Unset values — [L599](references/opentelemetry-specification/v1.55.0/trace/api.md#L599)
- [ ] Status code SHOULD remain unset except in documented circumstances — [L602](references/opentelemetry-specification/v1.55.0/trace/api.md#L602)
- [ ] An attempt to set value Unset SHOULD be ignored — [L603](references/opentelemetry-specification/v1.55.0/trace/api.md#L603)
- [ ] When status is set to Error by Instrumentation Libraries, Description SHOULD be documented and predictable — [L606](references/opentelemetry-specification/v1.55.0/trace/api.md#L606)
- [ ] Instrumentation Libraries SHOULD NOT set the status code to Ok unless explicitly configured — [L613](references/opentelemetry-specification/v1.55.0/trace/api.md#L613)
- [ ] Instrumentation Libraries SHOULD leave status code as Unset unless there is an error — [L614](references/opentelemetry-specification/v1.55.0/trace/api.md#L614)
- [ ] When span status is set to Ok it SHOULD be considered final and further attempts to change it SHOULD be ignored — [L619](references/opentelemetry-specification/v1.55.0/trace/api.md#L619)
- [ ] Analysis tools SHOULD respond to an Ok status by suppressing errors — [L622](references/opentelemetry-specification/v1.55.0/trace/api.md#L622)

### Span Operations — End

- [ ] Implementations SHOULD ignore all subsequent calls to End and other Span methods after Span is finished — [L652](references/opentelemetry-specification/v1.55.0/trace/api.md#L652)
- [ ] All API implementations of end-like methods MUST internally call the End method — [L659](references/opentelemetry-specification/v1.55.0/trace/api.md#L659)
- [ ] End MUST NOT have any effects on child spans — [L662](references/opentelemetry-specification/v1.55.0/trace/api.md#L662)
- [ ] End MUST NOT inactivate the Span in any Context it is active in — [L665](references/opentelemetry-specification/v1.55.0/trace/api.md#L665)
- [ ] It MUST still be possible to use an ended span as parent via a Context — [L666](references/opentelemetry-specification/v1.55.0/trace/api.md#L666)
- [ ] If end timestamp is omitted, it MUST be treated equivalent to passing the current time — [L673](references/opentelemetry-specification/v1.55.0/trace/api.md#L673)
- [ ] End operation itself MUST NOT perform blocking I/O on the calling thread — [L677](references/opentelemetry-specification/v1.55.0/trace/api.md#L677)
- [ ] Any locking used SHOULD be minimized and SHOULD be removed entirely if possible — [L678](references/opentelemetry-specification/v1.55.0/trace/api.md#L678)

### Span Operations — Record Exception

- [ ] Languages SHOULD provide a RecordException method if the language uses exceptions — [L686](references/opentelemetry-specification/v1.55.0/trace/api.md#L686)
- [ ] RecordException MUST record an exception as an Event with the conventions outlined in the exceptions document — [L693](references/opentelemetry-specification/v1.55.0/trace/api.md#L693)
- [ ] The minimum required argument SHOULD be no more than only an exception object — [L695](references/opentelemetry-specification/v1.55.0/trace/api.md#L695)
- [ ] If RecordException is provided, it MUST accept an optional parameter for additional event attributes — [L697](references/opentelemetry-specification/v1.55.0/trace/api.md#L697)
- [ ] Additional attributes SHOULD be done in the same way as for the AddEvent method — [L699](references/opentelemetry-specification/v1.55.0/trace/api.md#L699)

### Span Lifetime

- [ ] Start and end time as well as Event timestamps MUST be recorded at time of calling corresponding API — [L715](references/opentelemetry-specification/v1.55.0/trace/api.md#L715)

### Wrapping a SpanContext in a Span

- [ ] API MUST provide an operation for wrapping a SpanContext with an object implementing the Span interface — [L720](references/opentelemetry-specification/v1.55.0/trace/api.md#L720)
- [ ] If a new type is required, it SHOULD NOT be exposed publicly if possible — [L724](references/opentelemetry-specification/v1.55.0/trace/api.md#L724)
- [ ] If a new type must be publicly exposed, it SHOULD be named NonRecordingSpan — [L727](references/opentelemetry-specification/v1.55.0/trace/api.md#L727)
- [ ] GetContext MUST return the wrapped SpanContext — [L731](references/opentelemetry-specification/v1.55.0/trace/api.md#L731)
- [ ] IsRecording MUST return false — [L732](references/opentelemetry-specification/v1.55.0/trace/api.md#L732)
- [ ] Remaining functionality of Span MUST be defined as no-op operations — [L735](references/opentelemetry-specification/v1.55.0/trace/api.md#L735)
- [ ] This functionality MUST be fully implemented in the API and SHOULD NOT be overridable — [L739](references/opentelemetry-specification/v1.55.0/trace/api.md#L739)

### Link

- [ ] A user MUST have the ability to record links to other SpanContexts — [L805](references/opentelemetry-specification/v1.55.0/trace/api.md#L805)
- [ ] API MUST provide an API to record a single Link — [L815](references/opentelemetry-specification/v1.55.0/trace/api.md#L815)
- [ ] Implementations SHOULD record links containing SpanContext with empty TraceId or SpanId as long as attribute set or TraceState is non-empty — [L821](references/opentelemetry-specification/v1.55.0/trace/api.md#L821)
- [ ] Span SHOULD preserve the order in which Links are set — [L830](references/opentelemetry-specification/v1.55.0/trace/api.md#L830)
- [ ] API documentation MUST state that adding links at span creation is preferred to calling AddLink later — [L832](references/opentelemetry-specification/v1.55.0/trace/api.md#L832)

### Concurrency requirements

- [ ] TracerProvider — all methods MUST be safe for concurrent use — [L842](references/opentelemetry-specification/v1.55.0/trace/api.md#L842)
- [ ] Tracer — all methods MUST be safe for concurrent use — [L845](references/opentelemetry-specification/v1.55.0/trace/api.md#L845)
- [ ] Span — all methods MUST be safe for concurrent use — [L848](references/opentelemetry-specification/v1.55.0/trace/api.md#L848)
- [ ] Event — Events are immutable and MUST be safe for concurrent use — [L851](references/opentelemetry-specification/v1.55.0/trace/api.md#L851)
- [ ] Link — Links are immutable and SHOULD be safe for concurrent use — [L853](references/opentelemetry-specification/v1.55.0/trace/api.md#L853)

### Behavior of the API in the absence of an installed SDK

- [ ] API MUST return a non-recording Span with the SpanContext in the parent Context — [L865](references/opentelemetry-specification/v1.55.0/trace/api.md#L865)
- [ ] If Span in parent Context is already non-recording, it SHOULD be returned directly without instantiating a new Span — [L867](references/opentelemetry-specification/v1.55.0/trace/api.md#L867)
- [ ] If parent Context contains no Span, an empty non-recording Span MUST be returned — [L869](references/opentelemetry-specification/v1.55.0/trace/api.md#L869)

## Trace SDK

> Ref: [trace/sdk.md](references/opentelemetry-specification/v1.55.0/trace/sdk.md)

### TracerProvider — Tracer Creation

- [ ] It SHOULD only be possible to create Tracer instances through a TracerProvider — [L95](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L95)
- [ ] TracerProvider MUST implement the Get a Tracer API — [L98](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L98)
- [ ] The input provided by the user MUST be used to create an InstrumentationScope instance stored on the Tracer — [L100](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L100)

### TracerProvider — Configuration

- [ ] Configuration (SpanProcessors, IdGenerator, SpanLimits, Sampler) MUST be owned by the TracerProvider — [L113](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L113)
- [ ] If configuration is updated, the updated configuration MUST also apply to all already returned Tracers — [L119](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L119)
- [ ] It MUST NOT matter whether a Tracer was obtained before or after the configuration change — [L120](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L120)

### TracerProvider — Shutdown

- [ ] Shutdown MUST be called only once for each TracerProvider instance — [L161](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L161)
- [ ] After Shutdown, SDKs SHOULD return a valid no-op Tracer for subsequent get-Tracer calls — [L163](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L163)
- [ ] Shutdown SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L165](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L165)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L168](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L168)
- [ ] Shutdown MUST be implemented at least by invoking Shutdown within all internal processors — [L173](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L173)

### TracerProvider — ForceFlush

- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L179](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L179)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L182](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L182)
- [ ] ForceFlush MUST invoke ForceFlush on all registered SpanProcessors — [L187](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L187)

### Additional Span Interfaces

- [ ] Readable span: function MUST be able to access all information that was added to the span — [L242](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L242)
- [ ] Readable span: function MUST be able to access the InstrumentationScope and Resource information — [L249](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L249)
- [ ] Readable span: function MUST also be able to access the InstrumentationLibrary (deprecated) — [L251](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L251)
- [ ] Readable span: function MUST be able to reliably determine whether the Span has ended — [L255](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L255)
- [ ] Readable span: counts for dropped attributes, events and links MUST be available for exporters — [L260](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L260)
- [ ] Readable span: implementations MUST expose at least the full parent SpanContext — [L266](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L266)
- [ ] Read/write span: it MUST be possible to obtain the same Span instance that the span creation API returned to the user — [L283](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L283)

### Sampling

- [ ] Span Processor MUST receive only spans which have IsRecording set to true — [L304](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L304)
- [ ] Span Exporter SHOULD NOT receive spans unless the Sampled flag was also set — [L305](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L305)
- [ ] Span Exporters MUST receive spans which have Sampled flag set to true — [L310](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L310)
- [ ] Span Exporters SHOULD NOT receive spans that do not have Sampled flag set — [L311](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L311)
- [ ] SDK MUST NOT allow combination of SampledFlag == true and IsRecording == false — [L320](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L320)

### SDK Span Creation

- [ ] When asked to create a Span, the SDK MUST act as if doing the following in order (generate/use trace ID, query sampler, generate span ID, create span) — [L339](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L339)

### Sampler — ShouldSample

- [ ] If parent SpanContext contains a valid TraceId, it MUST always match the TraceId argument — [L380](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L380)
- [ ] RECORD_ONLY decision: Sampled flag MUST NOT be set — [L398](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L398)
- [ ] RECORD_AND_SAMPLE decision: Sampled flag MUST be set — [L399](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L399)
- [ ] Samplers SHOULD normally return the passed-in Tracestate if they do not intend to change it — [L405](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L405)

### Sampler — GetDescription

- [ ] Callers SHOULD NOT cache the returned value of GetDescription — [L416](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L416)

### Built-in Samplers — AlwaysOn

- [ ] Description MUST be `AlwaysOnSampler` — [L426](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L426)

### Built-in Samplers — AlwaysOff

- [ ] Description MUST be `AlwaysOffSampler` — [L431](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L431)

### Built-in Samplers — TraceIdRatioBased

- [ ] TraceIdRatioBased MUST ignore the parent SampledFlag — [L447](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L447)
- [ ] Description MUST return a string of the form `"TraceIdRatioBased{RATIO}"` — [L450](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L450)
- [ ] Description precision SHOULD be high enough to identify different ratios — [L453](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L453)
- [ ] Sampling algorithm MUST be deterministic (deterministic hash of TraceId) — [L462](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L462)
- [ ] A TraceIdRatioBased sampler with a given probability MUST also sample all traces that a lower probability sampler would sample — [L467](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L467)

### Span Limits

- [ ] Span attributes MUST adhere to the common rules of attribute limits — [L836](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L836)
- [ ] If SDK implements span limits, it MUST provide a way to change these limits via TracerProvider configuration — [L841](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L841)
- [ ] The name of the configuration options SHOULD be EventCountLimit and LinkCountLimit — [L845](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L845)
- [ ] Options class SHOULD be called SpanLimits — [L846](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L846)
- [ ] There SHOULD be a message printed in the SDK's log when attribute/event/link is discarded due to limit — [L873](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L873)
- [ ] Discard message MUST be printed at most once per span — [L875](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L875)

### Id Generators

- [ ] SDK MUST by default randomly generate both the TraceId and the SpanId — [L880](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L880)
- [ ] SDK MUST provide a mechanism for customizing the way IDs are generated — [L882](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L882)
- [ ] Method names MUST be consistent with SpanContext (retrieving TraceId and SpanId) — [L887](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L887)
- [ ] Additional IdGenerator for vendor-specific protocols MUST NOT be maintained in Core OpenTelemetry repositories — [L899](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L899)

### Span Processor — Interface Definition

- [ ] SpanProcessor interface MUST declare OnStart, OnEnd, Shutdown, and ForceFlush methods — [L952](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L952)
- [ ] SpanProcessor interface SHOULD declare OnEnding method — [L959](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L959)

### Span Processor — OnStart

- [ ] OnStart `span` parameter: it SHOULD be possible to keep a reference to the span object and updates SHOULD be reflected in it — [L973](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L973)

### Span Processor — OnEnd

- [ ] OnEnd MUST be called synchronously within the Span.End() API — [L1008](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1008)

### Span Processor — Shutdown

- [ ] Shutdown SHOULD be called only once for each SpanProcessor instance — [L1024](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1024)
- [ ] After Shutdown, SDKs SHOULD ignore subsequent calls to OnStart, OnEnd, or ForceFlush gracefully — [L1026](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1026)
- [ ] Shutdown SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1028](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1028)
- [ ] Shutdown MUST include the effects of ForceFlush — [L1031](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1031)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L1033](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1033)

### Span Processor — ForceFlush

- [ ] SpanProcessor ForceFlush: tasks for already-received Spans SHOULD be completed as soon as possible — [L1041](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1041)
- [ ] If SpanProcessor has an associated exporter, it SHOULD try to call Export and then ForceFlush on it — [L1044](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1044)
- [ ] Built-in SpanProcessors MUST call Export and ForceFlush on their exporter — [L1047](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1047)
- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1052](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1052)
- [ ] ForceFlush SHOULD only be called in cases where absolutely necessary — [L1055](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1055)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L1059](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1059)

### Built-in Span Processors

- [ ] Standard SDK MUST implement both simple and batch processors — [L1066](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1066)

### Built-in Span Processors — Simple Processor

- [ ] Simple processor MUST synchronize calls to Span Exporter's Export to avoid concurrent invocations — [L1076](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1076)

### Built-in Span Processors — Batching Processor

- [ ] Batching processor MUST synchronize calls to Span Exporter's Export to avoid concurrent invocations — [L1089](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1089)
- [ ] Processor SHOULD export a batch when scheduledDelay expires, queue reaches maxExportBatchSize, or ForceFlush is called — [L1092](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1092)

### Span Exporter — Interface Definition

- [ ] Each exporter implementation MUST document the concurrency characteristics the SDK requires — [L1130](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1130)
- [ ] Exporter MUST support three functions: Export, Shutdown, and ForceFlush — [L1135](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1135)

### Span Exporter — Export

- [ ] Export MUST NOT block indefinitely; there MUST be a reasonable upper limit after which the call times out with Failure — [L1156](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1156)
- [ ] Default SDK's Span Processors SHOULD NOT implement retry logic — [L1160](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1160)

### Span Exporter — ForceFlush

- [ ] Exporter ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1208](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1208)
- [ ] Exporter ForceFlush SHOULD only be called in cases where absolutely necessary — [L1211](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1211)
- [ ] Exporter ForceFlush SHOULD complete or abort within some timeout — [L1215](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1215)

### Concurrency requirements

- [ ] Tracer Provider: Tracer creation, ForceFlush and Shutdown MUST be safe to be called concurrently — [L1281](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1281)
- [ ] Sampler: ShouldSample and GetDescription MUST be safe to be called concurrently — [L1284](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1284)
- [ ] Span processor: all methods MUST be safe to be called concurrently — [L1287](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1287)
- [ ] Span Exporter: ForceFlush and Shutdown MUST be safe to be called concurrently — [L1289](references/opentelemetry-specification/v1.55.0/trace/sdk.md#L1289)

## Trace Exporters

### Console (stdout)

> Ref: [trace/sdk_exporters/stdout.md](references/opentelemetry-specification/v1.55.0/trace/sdk_exporters/stdout.md)

- [ ] Documentation SHOULD warn users that the output format is unspecified and can vary between implementations — [L14](references/opentelemetry-specification/v1.55.0/trace/sdk_exporters/stdout.md#L14)
- [ ] By default the stdout exporter SHOULD be paired with a simple processor — [L34](references/opentelemetry-specification/v1.55.0/trace/sdk_exporters/stdout.md#L34)

## Metrics API

> Ref: [metrics/api.md](references/opentelemetry-specification/v1.55.0/metrics/api.md)

### MeterProvider

- [ ] API SHOULD provide a way to set/register and access a global default MeterProvider — [L111](references/opentelemetry-specification/v1.55.0/metrics/api.md#L111)
- [ ] MeterProvider MUST provide the function: Get a Meter — [L116](references/opentelemetry-specification/v1.55.0/metrics/api.md#L116)

### Get a Meter

- [ ] Get a Meter API MUST accept `name` parameter — [L122](references/opentelemetry-specification/v1.55.0/metrics/api.md#L122)
- [ ] Get a Meter API MUST NOT obligate a user to provide `version` — [L138](references/opentelemetry-specification/v1.55.0/metrics/api.md#L138)
- [ ] Get a Meter API MUST NOT obligate a user to provide `schema_url` — [L144](references/opentelemetry-specification/v1.55.0/metrics/api.md#L144)
- [ ] Get a Meter API MUST be structured to accept a variable number of `attributes`, including none — [L150](references/opentelemetry-specification/v1.55.0/metrics/api.md#L150)

### Meter

- [ ] Meter SHOULD NOT be responsible for the configuration — [L161](references/opentelemetry-specification/v1.55.0/metrics/api.md#L161)
- [ ] Meter MUST provide functions to create new Instruments (Counter, Async Counter, Histogram, Gauge, Async Gauge, UpDownCounter, Async UpDownCounter) — [L166](references/opentelemetry-specification/v1.55.0/metrics/api.md#L166)

### Instrument

- [ ] Language-level features such as integer vs floating point SHOULD be considered as identifying — [L194](references/opentelemetry-specification/v1.55.0/metrics/api.md#L194)

### Instrument unit

- [ ] Unit MUST be case-sensitive, ASCII string — [L225](references/opentelemetry-specification/v1.55.0/metrics/api.md#L225)
- [ ] API SHOULD treat unit as an opaque string — [L223](references/opentelemetry-specification/v1.55.0/metrics/api.md#L223)

### Instrument description

- [ ] API MUST treat description as an opaque string — [L235](references/opentelemetry-specification/v1.55.0/metrics/api.md#L235)
- [ ] Description MUST support BMP (Unicode Plane 0) — [L237](references/opentelemetry-specification/v1.55.0/metrics/api.md#L237)
- [ ] Description MUST support at least 1023 characters — [L242](references/opentelemetry-specification/v1.55.0/metrics/api.md#L242)

### Instrument advisory parameters (Mixed top-level, sub-sections checked individually)

#### ExplicitBucketBoundaries (Stable)

- [ ] OpenTelemetry SDKs MUST handle advisory parameters as described in sdk.md — [L254](references/opentelemetry-specification/v1.55.0/metrics/api.md#L254)

### Synchronous Instrument API

- [ ] API to construct synchronous instruments MUST accept `name` parameter — [L304](references/opentelemetry-specification/v1.55.0/metrics/api.md#L304)
- [ ] API SHOULD be structured so a user is obligated to provide `name` — [L308](references/opentelemetry-specification/v1.55.0/metrics/api.md#L308)
- [ ] If not structurally enforced, API MUST be documented to communicate `name` is needed — [L310](references/opentelemetry-specification/v1.55.0/metrics/api.md#L310)
- [ ] API SHOULD be documented that `name` needs to conform to instrument name syntax — [L313](references/opentelemetry-specification/v1.55.0/metrics/api.md#L313)
- [ ] API SHOULD NOT validate the `name` — [L315](references/opentelemetry-specification/v1.55.0/metrics/api.md#L315)
- [ ] API MUST NOT obligate a user to provide `unit` — [L320](references/opentelemetry-specification/v1.55.0/metrics/api.md#L320)
- [ ] API MUST accept a case-sensitive string for `unit` that supports ASCII and at least 63 characters — [L324](references/opentelemetry-specification/v1.55.0/metrics/api.md#L324)
- [ ] API SHOULD NOT validate the `unit` — [L326](references/opentelemetry-specification/v1.55.0/metrics/api.md#L326)
- [ ] API MUST NOT obligate a user to provide `description` — [L331](references/opentelemetry-specification/v1.55.0/metrics/api.md#L331)
- [ ] API MUST accept a string for `description` that supports BMP and at least 1023 characters — [L334](references/opentelemetry-specification/v1.55.0/metrics/api.md#L334)
- [ ] API MUST NOT obligate the user to provide `advisory` parameters — [L343](references/opentelemetry-specification/v1.55.0/metrics/api.md#L343)
- [ ] API SHOULD NOT validate `advisory` parameters — [L348](references/opentelemetry-specification/v1.55.0/metrics/api.md#L348)

### Asynchronous Instrument API

- [ ] API to construct asynchronous instruments MUST accept `name` parameter — [L357](references/opentelemetry-specification/v1.55.0/metrics/api.md#L357)
- [ ] API SHOULD be structured so a user is obligated to provide `name` — [L361](references/opentelemetry-specification/v1.55.0/metrics/api.md#L361)
- [ ] If not structurally enforced, API MUST be documented to communicate `name` is needed — [L363](references/opentelemetry-specification/v1.55.0/metrics/api.md#L363)
- [ ] API SHOULD be documented that `name` needs to conform to instrument name syntax — [L366](references/opentelemetry-specification/v1.55.0/metrics/api.md#L366)
- [ ] API SHOULD NOT validate the `name` — [L368](references/opentelemetry-specification/v1.55.0/metrics/api.md#L368)
- [ ] API MUST NOT obligate a user to provide `unit` — [L373](references/opentelemetry-specification/v1.55.0/metrics/api.md#L373)
- [ ] API MUST accept a case-sensitive string for `unit` that supports ASCII and at least 63 characters — [L377](references/opentelemetry-specification/v1.55.0/metrics/api.md#L377)
- [ ] API SHOULD NOT validate the `unit` — [L379](references/opentelemetry-specification/v1.55.0/metrics/api.md#L379)
- [ ] API MUST NOT obligate a user to provide `description` — [L383](references/opentelemetry-specification/v1.55.0/metrics/api.md#L383)
- [ ] API MUST accept a string for `description` that supports BMP and at least 1023 characters — [L387](references/opentelemetry-specification/v1.55.0/metrics/api.md#L387)
- [ ] API MUST NOT obligate the user to provide `advisory` parameters — [L395](references/opentelemetry-specification/v1.55.0/metrics/api.md#L395)
- [ ] API SHOULD NOT validate `advisory` parameters — [L400](references/opentelemetry-specification/v1.55.0/metrics/api.md#L400)
- [ ] API MUST be structured to accept a variable number of `callback` functions, including none — [L405](references/opentelemetry-specification/v1.55.0/metrics/api.md#L405)
- [ ] API MUST support creation of asynchronous instruments by passing zero or more callbacks — [L408](references/opentelemetry-specification/v1.55.0/metrics/api.md#L408)
- [ ] API SHOULD support registration of callback functions after instrument creation — [L415](references/opentelemetry-specification/v1.55.0/metrics/api.md#L415)
- [ ] User MUST be able to undo registration of a specific callback after registration — [L419](references/opentelemetry-specification/v1.55.0/metrics/api.md#L419)
- [ ] Every registered Callback MUST be evaluated exactly once during collection prior to reading data — [L422](references/opentelemetry-specification/v1.55.0/metrics/api.md#L422)
- [ ] Callback functions MUST be documented: SHOULD be reentrant safe — [L428](references/opentelemetry-specification/v1.55.0/metrics/api.md#L428)
- [ ] Callback functions MUST be documented: SHOULD NOT take indefinite time — [L430](references/opentelemetry-specification/v1.55.0/metrics/api.md#L430)
- [ ] Callback functions MUST be documented: SHOULD NOT make duplicate observations — [L431](references/opentelemetry-specification/v1.55.0/metrics/api.md#L431)
- [ ] Callbacks registered at instrument creation MUST apply to the single instrument under construction — [L446](references/opentelemetry-specification/v1.55.0/metrics/api.md#L446)
- [ ] Idiomatic APIs for multiple-instrument Callbacks MUST distinguish the instrument associated with each Measurement — [L452](references/opentelemetry-specification/v1.55.0/metrics/api.md#L452)
- [ ] Multiple-instrument Callbacks MUST be associated with a declared set of async instruments from the same Meter — [L455](references/opentelemetry-specification/v1.55.0/metrics/api.md#L455)
- [ ] API MUST treat observations from a single Callback as logically at a single instant with identical timestamps — [L462](references/opentelemetry-specification/v1.55.0/metrics/api.md#L462)
- [ ] API SHOULD provide some way to pass `state` to the callback — [L467](references/opentelemetry-specification/v1.55.0/metrics/api.md#L467)

### General operations (Enabled)

- [ ] All synchronous instruments SHOULD provide function to report if instrument is Enabled — [L475](references/opentelemetry-specification/v1.55.0/metrics/api.md#L475)
- [ ] Enabled API MUST be structured in a way for parameters to be added — [L487](references/opentelemetry-specification/v1.55.0/metrics/api.md#L487)
- [ ] Enabled API MUST return a language idiomatic boolean type — [L489](references/opentelemetry-specification/v1.55.0/metrics/api.md#L489)
- [ ] Enabled API SHOULD be documented that authors need to call it each time they record a measurement — [L494](references/opentelemetry-specification/v1.55.0/metrics/api.md#L494)

### Counter

- [ ] There MUST NOT be any API for creating a Counter other than with a Meter — [L512](references/opentelemetry-specification/v1.55.0/metrics/api.md#L512)

#### Counter Add

- [ ] Add API SHOULD NOT return a value — [L549](references/opentelemetry-specification/v1.55.0/metrics/api.md#L549)
- [ ] Add API MUST accept a numeric increment value — [L552](references/opentelemetry-specification/v1.55.0/metrics/api.md#L552)
- [ ] Add API SHOULD be structured so user is obligated to provide increment value — [L557](references/opentelemetry-specification/v1.55.0/metrics/api.md#L557)
- [ ] If not structurally enforced, Add API MUST be documented to communicate increment is needed — [L558](references/opentelemetry-specification/v1.55.0/metrics/api.md#L558)
- [ ] Increment value SHOULD be documented as expected to be non-negative — [L562](references/opentelemetry-specification/v1.55.0/metrics/api.md#L562)
- [ ] Add API SHOULD NOT validate increment value — [L563](references/opentelemetry-specification/v1.55.0/metrics/api.md#L563)
- [ ] Add API MUST be structured to accept a variable number of attributes, including none — [L569](references/opentelemetry-specification/v1.55.0/metrics/api.md#L569)
- [ ] API MUST allow callers to provide flexible attributes at invocation time — [L577](references/opentelemetry-specification/v1.55.0/metrics/api.md#L577)

### Asynchronous Counter

- [ ] There MUST NOT be any API for creating an Async Counter other than with a Meter — [L615](references/opentelemetry-specification/v1.55.0/metrics/api.md#L615)
- [ ] API MUST treat observations from a single callback as logically at a single instant with identical timestamps — [L652](references/opentelemetry-specification/v1.55.0/metrics/api.md#L652)
- [ ] API SHOULD provide some way to pass `state` to the callback — [L655](references/opentelemetry-specification/v1.55.0/metrics/api.md#L655)

### Histogram

- [ ] There MUST NOT be any API for creating a Histogram other than with a Meter — [L748](references/opentelemetry-specification/v1.55.0/metrics/api.md#L748)

#### Histogram Record

- [ ] Record API SHOULD NOT return a value — [L785](references/opentelemetry-specification/v1.55.0/metrics/api.md#L785)
- [ ] Record API MUST accept a numeric value to record — [L788](references/opentelemetry-specification/v1.55.0/metrics/api.md#L788)
- [ ] Record API SHOULD be structured so user is obligated to provide value — [L792](references/opentelemetry-specification/v1.55.0/metrics/api.md#L792)
- [ ] If not structurally enforced, Record API MUST be documented to communicate value is needed — [L794](references/opentelemetry-specification/v1.55.0/metrics/api.md#L794)
- [ ] Record value SHOULD be documented as expected to be non-negative — [L797](references/opentelemetry-specification/v1.55.0/metrics/api.md#L797)
- [ ] Record API SHOULD NOT validate value — [L799](references/opentelemetry-specification/v1.55.0/metrics/api.md#L799)
- [ ] Record API MUST be structured to accept a variable number of attributes, including none — [L804](references/opentelemetry-specification/v1.55.0/metrics/api.md#L804)
- [ ] API MUST allow callers to provide flexible attributes at invocation time — [L902](references/opentelemetry-specification/v1.55.0/metrics/api.md#L902)

### Gauge

- [ ] There MUST NOT be any API for creating a Gauge other than with a Meter — [L854](references/opentelemetry-specification/v1.55.0/metrics/api.md#L854)

#### Gauge Record

- [ ] Record API SHOULD NOT return a value — [L880](references/opentelemetry-specification/v1.55.0/metrics/api.md#L880)
- [ ] Record API MUST accept a numeric value (current absolute value) — [L883](references/opentelemetry-specification/v1.55.0/metrics/api.md#L883)
- [ ] Record API SHOULD be structured so user is obligated to provide value — [L888](references/opentelemetry-specification/v1.55.0/metrics/api.md#L888)
- [ ] If not structurally enforced, Record API MUST be documented to communicate value is needed — [L889](references/opentelemetry-specification/v1.55.0/metrics/api.md#L889)
- [ ] Record API MUST be structured to accept a variable number of attributes, including none — [L894](references/opentelemetry-specification/v1.55.0/metrics/api.md#L894)
- [ ] API MUST allow callers to provide flexible attributes at invocation time — [L902](references/opentelemetry-specification/v1.55.0/metrics/api.md#L902)

### Asynchronous Gauge

- [ ] There MUST NOT be any API for creating an Async Gauge other than with a Meter — [L936](references/opentelemetry-specification/v1.55.0/metrics/api.md#L936)

### UpDownCounter

- [ ] There MUST NOT be any API for creating an UpDownCounter other than with a Meter — [L1086](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1086)

#### UpDownCounter Add

- [ ] Add API SHOULD NOT return a value — [L1122](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1122)
- [ ] Add API MUST accept a numeric value to add — [L1125](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1125)
- [ ] Add API SHOULD be structured so user is obligated to provide value — [L1129](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1129)
- [ ] If not structurally enforced, Add API MUST be documented to communicate value is needed — [L1131](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1131)
- [ ] Add API MUST be structured to accept a variable number of attributes, including none — [L1136](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1136)

### Asynchronous UpDownCounter

- [ ] There MUST NOT be any API for creating an Async UpDownCounter other than with a Meter — [L1178](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1178)

### Measurement

- [ ] Multiple-instrument callbacks API SHOULD accept a callback function and a list of Instruments — [L1294](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1294)

### Compatibility requirements

- [ ] All metrics components SHOULD allow new APIs to be added without breaking changes — [L1334](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1334)
- [ ] All metrics APIs SHOULD allow optional parameters to be added without breaking changes — [L1337](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1337)

### Concurrency requirements

- [ ] MeterProvider: all methods MUST be documented as safe for concurrent use — [L1345](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1345)
- [ ] Meter: all methods MUST be documented as safe for concurrent use — [L1348](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1348)
- [ ] Instrument: all methods MUST be documented as safe for concurrent use — [L1351](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1351)

---

## Metrics SDK

> Ref: [metrics/sdk.md](references/opentelemetry-specification/v1.55.0/metrics/sdk.md)

### MeterProvider (Stable)

- [ ] All language implementations MUST provide an SDK — [L103](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L103)
- [ ] MeterProvider MUST provide a way to specify a Resource — [L109](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L109)
- [ ] Resource SHOULD be associated with all metrics produced by any Meter from the MeterProvider — [L110](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L110)

#### MeterProvider Creation

- [ ] SDK SHOULD allow creation of multiple independent MeterProviders — [L117](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L117)

#### Meter Creation

- [ ] It SHOULD only be possible to create Meter instances through a MeterProvider — [L121](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L121)
- [ ] MeterProvider MUST implement the Get a Meter API — [L124](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L124)
- [ ] Input provided by the user MUST be used to create an InstrumentationScope stored on the Meter — [L126](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L126)
- [ ] For invalid name, a working Meter MUST be returned as fallback — [L131](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L131)
- [ ] Invalid name Meter's name SHOULD keep the original invalid value — [L132](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L132)
- [ ] A message reporting invalid name SHOULD be logged — [L133](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L133)

#### Configuration

- [ ] Configuration (MetricExporters, MetricReaders, Views) MUST be owned by the MeterProvider — [L144](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L144)
- [ ] If configuration is updated, it MUST also apply to all already returned Meters — [L150](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L150)

#### Shutdown

- [ ] Shutdown MUST be called only once for each MeterProvider instance — [L191](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L191)
- [ ] After Shutdown, SDKs SHOULD return a valid no-op Meter for subsequent get-Meter calls — [L193](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L193)
- [ ] Shutdown SHOULD provide a way to let caller know whether it succeeded, failed or timed out — [L195](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L195)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L198](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L198)
- [ ] Shutdown MUST be implemented at least by invoking Shutdown on all registered MetricReaders and MetricExporters — [L203](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L203)

#### ForceFlush

- [ ] ForceFlush MUST invoke ForceFlush on all registered MetricReader instances that implement it — [L216](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L216)
- [ ] ForceFlush SHOULD provide a way to let caller know whether it succeeded, failed or timed out — [L219](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L219)
- [ ] ForceFlush SHOULD return ERROR status on error, NO ERROR otherwise — [L220](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L220)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L225](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L225)

#### View

- [ ] SDK MUST provide functionality for a user to create Views for a MeterProvider — [L252](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L252)
- [ ] View creation MUST accept Instrument selection criteria and resulting stream configuration — [L253](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L253)
- [ ] SDK MUST provide the means to register Views with a MeterProvider — [L257](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L257)
- [ ] Instrument selection criteria SHOULD be treated as additive — [L264](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L264)

#### Instrument selection criteria

- [ ] SDK MUST accept `name` criterion — [L270](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L270)
- [ ] SDK MUST recognize the single asterisk (`*`) as matching all Instruments — [L289](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L289)
- [ ] `name` criterion MUST NOT obligate a user to provide one — [L293](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L293)
- [ ] SDK MUST accept `type` criterion; MUST NOT obligate a user to provide one — [L299](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L299)
- [ ] SDK MUST accept `unit` criterion; MUST NOT obligate a user to provide one — [L305](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L305)
- [ ] SDK MUST accept `meter_name` criterion; MUST NOT obligate a user to provide one — [L311](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L311)
- [ ] SDK MUST accept `meter_version` criterion; MUST NOT obligate a user to provide one — [L317](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L317)
- [ ] SDK MUST accept `meter_schema_url` criterion; MUST NOT obligate a user to provide one — [L324](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L324)
- [ ] Additional criteria MUST NOT obligate a user to provide them — [L331](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L331)

#### Stream configuration

- [ ] SDK MUST accept `name` stream configuration parameter — [L339](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L339)
- [ ] View with `name` SHOULD have an instrument selector that selects at most one instrument — [L343](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L343)
- [ ] `name` MUST NOT obligate a user to provide one — [L352](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L352)
- [ ] If user does not provide `name`, name from the matched Instrument MUST be used by default — [L353](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L353)
- [ ] `description` SHOULD be used for the metric stream description — [L355](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L355)
- [ ] `description` MUST NOT obligate a user to provide one — [L360](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L360)
- [ ] If user does not provide `description`, description from the matched Instrument MUST be used by default — [L361](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L361)
- [ ] `attribute_keys` allow-list: identified attributes MUST be kept; all others MUST be ignored — [L364](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L364)
- [ ] `attribute_keys` MUST NOT obligate a user to provide them — [L372](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L372)
- [ ] If no `attribute_keys` provided, SDK SHOULD use Attributes advisory parameter; if absent, all attributes MUST be kept — [L373](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L373)
- [ ] Implementations SHOULD support configuring an exclude-list of attribute keys — [L378](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L378)
- [ ] Exclude-list attribute keys MUST be excluded; all other attributes MUST be kept — [L380](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L380)
- [ ] `aggregation` MUST NOT obligate a user to provide one — [L390](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L390)
- [ ] If no `aggregation`, MeterProvider MUST apply default aggregation based on instrument type per MetricReader — [L391](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L391)
- [ ] `exemplar_reservoir` MUST NOT obligate a user to provide one — [L402](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L402)
- [ ] If no `exemplar_reservoir`, MeterProvider MUST apply default exemplar reservoir — [L404](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L404)
- [ ] `aggregation_cardinality_limit` MUST NOT obligate a user to provide one — [L413](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L413)
- [ ] If no `aggregation_cardinality_limit`, MeterProvider MUST apply the MetricReader's default cardinality limit — [L414](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L414)

#### Measurement processing

- [ ] SDK SHOULD use the specified logic to determine how to process Measurements — [L420](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L420)
- [ ] Instrument advisory parameters MUST be honored when no View is registered — [L428](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L428)
- [ ] If applying View results in conflicting metric identities, implementation SHOULD apply the View and emit warning — [L439](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L439)
- [ ] View settings MUST take precedence over advisory parameters — [L446](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L446)
- [ ] If Instrument matches no View, SDK SHOULD enable using default aggregation and temporality — [
Now I have all the data I need. Let me compile the complete checklist.

## Metrics API

> Ref: [metrics/api.md](references/opentelemetry-specification/v1.55.0/metrics/api.md)

### MeterProvider

- [ ] API SHOULD provide a way to set/register and access a global default MeterProvider — [L111](references/opentelemetry-specification/v1.55.0/metrics/api.md#L111)
- [ ] MeterProvider MUST provide the function: Get a Meter — [L116](references/opentelemetry-specification/v1.55.0/metrics/api.md#L116)

### Get a Meter

- [ ] Get a Meter API MUST accept `name` parameter — [L122](references/opentelemetry-specification/v1.55.0/metrics/api.md#L122)
- [ ] Get a Meter API MUST NOT obligate a user to provide a `version` — [L138](references/opentelemetry-specification/v1.55.0/metrics/api.md#L138)
- [ ] Get a Meter API MUST NOT obligate a user to provide a `schema_url` — [L144](references/opentelemetry-specification/v1.55.0/metrics/api.md#L144)
- [ ] Get a Meter API MUST be structured to accept a variable number of `attributes`, including none — [L150](references/opentelemetry-specification/v1.55.0/metrics/api.md#L150)

### Meter

- [ ] Meter SHOULD NOT be responsible for the configuration — [L161](references/opentelemetry-specification/v1.55.0/metrics/api.md#L161)
- [ ] Meter MUST provide functions to create new Instruments (Counter, Async Counter, Histogram, Gauge, Async Gauge, UpDownCounter, Async UpDownCounter) — [L166](references/opentelemetry-specification/v1.55.0/metrics/api.md#L166)

### Instrument

- [ ] Language-level features such as the distinction between integer and floating point numbers SHOULD be considered as identifying — [L194](references/opentelemetry-specification/v1.55.0/metrics/api.md#L194)

### Instrument Unit

- [ ] Unit MUST be case-sensitive, ASCII string — [L225](references/opentelemetry-specification/v1.55.0/metrics/api.md#L225)

### Instrument Description

- [ ] API MUST treat description as an opaque string — [L235](references/opentelemetry-specification/v1.55.0/metrics/api.md#L235)
- [ ] Description MUST support BMP (Unicode Plane 0) — [L237](references/opentelemetry-specification/v1.55.0/metrics/api.md#L237)
- [ ] Description MUST support at least 1023 characters — [L242](references/opentelemetry-specification/v1.55.0/metrics/api.md#L242)

### Instrument Advisory Parameters (Stable: ExplicitBucketBoundaries only)

- [ ] OpenTelemetry SDKs MUST handle advisory parameters as described in the SDK spec — [L254](references/opentelemetry-specification/v1.55.0/metrics/api.md#L254)

### Synchronous Instrument API

- [ ] API to construct synchronous instruments MUST accept `name` parameter — [L304](references/opentelemetry-specification/v1.55.0/metrics/api.md#L304)
- [ ] If not possible to structurally enforce `name`, API MUST be documented to communicate to users that `name` is needed — [L310](references/opentelemetry-specification/v1.55.0/metrics/api.md#L310)
- [ ] API SHOULD be documented that `name` needs to conform to the instrument name syntax — [L313](references/opentelemetry-specification/v1.55.0/metrics/api.md#L313)
- [ ] API SHOULD NOT validate the `name` — [L315](references/opentelemetry-specification/v1.55.0/metrics/api.md#L315)
- [ ] API MUST NOT obligate a user to provide a `unit` — [L320](references/opentelemetry-specification/v1.55.0/metrics/api.md#L320)
- [ ] API MUST accept a case-sensitive string for `unit` that supports ASCII and can hold at least 63 characters — [L324](references/opentelemetry-specification/v1.55.0/metrics/api.md#L324)
- [ ] API SHOULD NOT validate the `unit` — [L326](references/opentelemetry-specification/v1.55.0/metrics/api.md#L326)
- [ ] API MUST NOT obligate a user to provide a `description` — [L331](references/opentelemetry-specification/v1.55.0/metrics/api.md#L331)
- [ ] API MUST accept a string for `description` that supports BMP and holds at least 1023 characters — [L334](references/opentelemetry-specification/v1.55.0/metrics/api.md#L334)
- [ ] API MUST NOT obligate the user to provide `advisory` parameters — [L343](references/opentelemetry-specification/v1.55.0/metrics/api.md#L343)
- [ ] API SHOULD NOT validate `advisory` parameters — [L348](references/opentelemetry-specification/v1.55.0/metrics/api.md#L348)

### Asynchronous Instrument API

- [ ] API to construct asynchronous instruments MUST accept `name` parameter — [L357](references/opentelemetry-specification/v1.55.0/metrics/api.md#L357)
- [ ] If not possible to structurally enforce `name`, API MUST be documented to communicate to users that `name` is needed — [L363](references/opentelemetry-specification/v1.55.0/metrics/api.md#L363)
- [ ] API SHOULD be documented that `name` needs to conform to instrument name syntax — [L366](references/opentelemetry-specification/v1.55.0/metrics/api.md#L366)
- [ ] API SHOULD NOT validate the `name` — [L368](references/opentelemetry-specification/v1.55.0/metrics/api.md#L368)
- [ ] API MUST NOT obligate a user to provide a `unit` — [L374](references/opentelemetry-specification/v1.55.0/metrics/api.md#L374)
- [ ] API MUST accept a case-sensitive string for `unit` that supports ASCII and can hold at least 63 characters — [L377](references/opentelemetry-specification/v1.55.0/metrics/api.md#L377)
- [ ] API SHOULD NOT validate the `unit` — [L379](references/opentelemetry-specification/v1.55.0/metrics/api.md#L379)
- [ ] API MUST NOT obligate a user to provide a `description` — [L384](references/opentelemetry-specification/v1.55.0/metrics/api.md#L384)
- [ ] API MUST accept a string for `description` that supports BMP and holds at least 1023 characters — [L387](references/opentelemetry-specification/v1.55.0/metrics/api.md#L387)
- [ ] API MUST NOT obligate the user to provide `advisory` parameters — [L395](references/opentelemetry-specification/v1.55.0/metrics/api.md#L395)
- [ ] API MUST be structured to accept a variable number of `callback` functions, including none — [L405](references/opentelemetry-specification/v1.55.0/metrics/api.md#L405)
- [ ] API MUST support creation of asynchronous instruments by passing zero or more callback functions to be permanently registered — [L408](references/opentelemetry-specification/v1.55.0/metrics/api.md#L408)
- [ ] API SHOULD support registration of callback functions associated with asynchronous instruments after they are created — [L415](references/opentelemetry-specification/v1.55.0/metrics/api.md#L415)
- [ ] User MUST be able to undo registration of a specific callback after its registration — [L419](references/opentelemetry-specification/v1.55.0/metrics/api.md#L419)
- [ ] Every currently registered Callback associated with a set of instruments MUST be evaluated exactly once during collection — [L422](references/opentelemetry-specification/v1.55.0/metrics/api.md#L422)
- [ ] Callback functions MUST be documented as follows: SHOULD be reentrant safe, SHOULD NOT take indefinite time, SHOULD NOT make duplicate observations — [L426](references/opentelemetry-specification/v1.55.0/metrics/api.md#L426)
- [ ] Callbacks registered at the time of instrument creation MUST apply to the single instrument under construction — [L446](references/opentelemetry-specification/v1.55.0/metrics/api.md#L446)
- [ ] Idiomatic APIs for multiple-instrument Callbacks MUST distinguish the instrument associated with each observed Measurement — [L452](references/opentelemetry-specification/v1.55.0/metrics/api.md#L452)
- [ ] Multiple-instrument Callbacks MUST be associated at registration time with a declared set of asynchronous instruments from the same Meter — [L455](references/opentelemetry-specification/v1.55.0/metrics/api.md#L455)
- [ ] API MUST treat observations from a single Callback as logically taking place at a single instant with identical timestamps — [L462](references/opentelemetry-specification/v1.55.0/metrics/api.md#L462)
- [ ] API SHOULD provide some way to pass `state` to the callback — [L467](references/opentelemetry-specification/v1.55.0/metrics/api.md#L467)

### General Operations (Enabled)

- [ ] All synchronous instruments SHOULD provide function to report if instrument is Enabled — [L475](references/opentelemetry-specification/v1.55.0/metrics/api.md#L475)
- [ ] Enabled API MUST be structured in a way for parameters to be added — [L487](references/opentelemetry-specification/v1.55.0/metrics/api.md#L487)
- [ ] Enabled API MUST return a language idiomatic boolean type — [L489](references/opentelemetry-specification/v1.55.0/metrics/api.md#L489)
- [ ] Enabled API SHOULD be documented that instrumentation authors need to call it each time they record a measurement — [L494](references/opentelemetry-specification/v1.55.0/metrics/api.md#L494)

### Counter

- [ ] There MUST NOT be any API for creating a Counter other than with a Meter — [L512](references/opentelemetry-specification/v1.55.0/metrics/api.md#L512)

#### Counter Add

- [ ] Add API SHOULD NOT return a value — [L549](references/opentelemetry-specification/v1.55.0/metrics/api.md#L549)
- [ ] Add API MUST accept a numeric increment value — [L552](references/opentelemetry-specification/v1.55.0/metrics/api.md#L552)
- [ ] If not possible to structurally enforce increment value, API MUST be documented to communicate the parameter is needed — [L558](references/opentelemetry-specification/v1.55.0/metrics/api.md#L558)
- [ ] Increment value SHOULD be documented as expected to be non-negative — [L561](references/opentelemetry-specification/v1.55.0/metrics/api.md#L561)
- [ ] API SHOULD NOT validate the increment value — [L563](references/opentelemetry-specification/v1.55.0/metrics/api.md#L563)
- [ ] API MUST be structured to accept a variable number of attributes, including none — [L569](references/opentelemetry-specification/v1.55.0/metrics/api.md#L569)
- [ ] API MUST allow callers to provide flexible attributes at invocation time — [L577](references/opentelemetry-specification/v1.55.0/metrics/api.md#L577)

### Asynchronous Counter

- [ ] There MUST NOT be any API for creating an Asynchronous Counter other than with a Meter — [L615](references/opentelemetry-specification/v1.55.0/metrics/api.md#L615)
- [ ] API MUST treat observations from a single callback as logically taking place at a single instant with identical timestamps — [L651](references/opentelemetry-specification/v1.55.0/metrics/api.md#L651)
- [ ] API SHOULD provide some way to pass `state` to the callback — [L655](references/opentelemetry-specification/v1.55.0/metrics/api.md#L655)

### Histogram

- [ ] There MUST NOT be any API for creating a Histogram other than with a Meter — [L748](references/opentelemetry-specification/v1.55.0/metrics/api.md#L748)

#### Histogram Record

- [ ] Record API SHOULD NOT return a value — [L785](references/opentelemetry-specification/v1.55.0/metrics/api.md#L785)
- [ ] Record API MUST accept a numeric value to record — [L788](references/opentelemetry-specification/v1.55.0/metrics/api.md#L788)
- [ ] If not possible to structurally enforce value, API MUST be documented to communicate the parameter is needed — [L794](references/opentelemetry-specification/v1.55.0/metrics/api.md#L794)
- [ ] Value SHOULD be documented as expected to be non-negative — [L797](references/opentelemetry-specification/v1.55.0/metrics/api.md#L797)
- [ ] API SHOULD NOT validate the value — [L799](references/opentelemetry-specification/v1.55.0/metrics/api.md#L799)
- [ ] API MUST be structured to accept a variable number of attributes, including none — [L804](references/opentelemetry-specification/v1.55.0/metrics/api.md#L804)

### Gauge

- [ ] There MUST NOT be any API for creating a Gauge other than with a Meter — [L854](references/opentelemetry-specification/v1.55.0/metrics/api.md#L854)

#### Gauge Record

- [ ] Record API SHOULD NOT return a value — [L880](references/opentelemetry-specification/v1.55.0/metrics/api.md#L880)
- [ ] Record API MUST accept a numeric value — [L883](references/opentelemetry-specification/v1.55.0/metrics/api.md#L883)
- [ ] If not possible to structurally enforce value, API MUST be documented to communicate the parameter is needed — [L889](references/opentelemetry-specification/v1.55.0/metrics/api.md#L889)
- [ ] API MUST be structured to accept a variable number of attributes, including none — [L894](references/opentelemetry-specification/v1.55.0/metrics/api.md#L894)
- [ ] API MUST allow callers to provide flexible attributes at invocation time — [L902](references/opentelemetry-specification/v1.55.0/metrics/api.md#L902)

### Asynchronous Gauge

- [ ] There MUST NOT be any API for creating an Asynchronous Gauge other than with a Meter — [L936](references/opentelemetry-specification/v1.55.0/metrics/api.md#L936)

### UpDownCounter

- [ ] There MUST NOT be any API for creating an UpDownCounter other than with a Meter — [L1086](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1086)

#### UpDownCounter Add

- [ ] Add API SHOULD NOT return a value — [L1122](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1122)
- [ ] Add API MUST accept a numeric value to add — [L1125](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1125)
- [ ] If not possible to structurally enforce value, API MUST be documented to communicate the parameter is needed — [L1131](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1131)
- [ ] API MUST be structured to accept a variable number of attributes, including none — [L1136](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1136)

### Asynchronous UpDownCounter

- [ ] There MUST NOT be any API for creating an Asynchronous UpDownCounter other than with a Meter — [L1178](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1178)

### Multiple-instrument Callbacks

- [ ] API SHOULD support an interface allowing use of multiple instruments from a single registered Callback — [L1291](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1291)

### Compatibility Requirements

- [ ] All metrics components SHOULD allow new APIs to be added without introducing breaking changes — [L1334](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1334)
- [ ] All metrics APIs SHOULD allow optional parameters to be added without introducing breaking changes — [L1337](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1337)

### Concurrency Requirements

- [ ] MeterProvider: all methods MUST be documented as safe for concurrent use — [L1345](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1345)
- [ ] Meter: all methods MUST be documented as safe for concurrent use — [L1348](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1348)
- [ ] Instrument: all methods MUST be documented as safe for concurrent use — [L1351](references/opentelemetry-specification/v1.55.0/metrics/api.md#L1351)

---

## Metrics SDK

> Ref: [metrics/sdk.md](references/opentelemetry-specification/v1.55.0/metrics/sdk.md)

### General

- [ ] All language implementations of OpenTelemetry MUST provide an SDK — [L103](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L103)

### MeterProvider (Stable)

- [ ] MeterProvider MUST provide a way to allow a Resource to be specified — [L109](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L109)
- [ ] If a Resource is specified, it SHOULD be associated with all metrics produced by any Meter from the MeterProvider — [L110](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L110)

#### MeterProvider Creation

- [ ] SDK SHOULD allow the creation of multiple independent MeterProviders — [L117](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L117)

#### Meter Creation

- [ ] It SHOULD only be possible to create Meter instances through a MeterProvider — [L121](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L121)
- [ ] MeterProvider MUST implement the Get a Meter API — [L124](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L124)
- [ ] The input provided by the user MUST be used to create an InstrumentationScope instance stored on the created Meter — [L126](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L126)
- [ ] In the case where an invalid name is specified, a working Meter MUST be returned as a fallback — [L131](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L131)
- [ ] Invalid name Meter's name SHOULD keep the original invalid value — [L132](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L132)
- [ ] A message reporting that the specified value is invalid SHOULD be logged — [L133](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L133)

#### Configuration

- [ ] Configuration (MetricExporters, MetricReaders, Views) MUST be owned by the MeterProvider — [L144](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L144)
- [ ] If configuration is updated, the updated configuration MUST also apply to all already returned Meters — [L150](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L150)

#### Shutdown

- [ ] Shutdown MUST be called only once for each MeterProvider instance — [L191](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L191)
- [ ] After Shutdown, SDKs SHOULD return a valid no-op Meter for subsequent Get a Meter calls — [L193](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L193)
- [ ] Shutdown SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L196](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L196)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L198](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L198)
- [ ] Shutdown MUST be implemented at least by invoking Shutdown on all registered MetricReaders and MetricExporters — [L203](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L203)

#### ForceFlush

- [ ] ForceFlush MUST invoke ForceFlush on all registered MetricReader instances that implement ForceFlush — [L216](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L216)
- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L219](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L219)
- [ ] ForceFlush SHOULD return ERROR status if there is an error condition — [L220](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L220)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L225](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L225)

### View (Stable)

- [ ] SDK MUST provide functionality for a user to create Views for a MeterProvider — [L252](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L252)
- [ ] View creation MUST accept Instrument selection criteria and the resulting stream configuration — [L253](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L253)
- [ ] SDK MUST provide the means to register Views with a MeterProvider — [L257](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L257)

#### Instrument Selection Criteria

- [ ] Criteria SHOULD be treated as additive — [L264](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L264)
- [ ] SDK MUST accept the `name` criterion — [L270](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L270)
- [ ] If SDK does not support wildcards in general, it MUST still recognize the single asterisk (`*`) as matching all Instruments — [L288](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L288)
- [ ] `name` criterion MUST NOT obligate a user to provide one — [L293](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L293)
- [ ] `type` criterion MUST NOT obligate a user to provide one — [L299](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L299)
- [ ] `unit` criterion MUST NOT obligate a user to provide one — [L305](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L305)
- [ ] `meter_name` criterion MUST NOT obligate a user to provide one — [L311](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L311)
- [ ] `meter_version` criterion MUST NOT obligate a user to provide one — [L316](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L316)
- [ ] `meter_schema_url` criterion MUST NOT obligate a user to provide one — [L323](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L323)
- [ ] Additional criteria MUST NOT obligate a user to provide them — [L331](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L331)

#### Stream Configuration

- [ ] SDK MUST accept `name` stream configuration parameter — [L339](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L339)
- [ ] View with `name` SHOULD have instrument selector that selects at most one instrument — [L343](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L343)
- [ ] Stream configuration `name` MUST NOT obligate a user to provide one — [L352](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L352)
- [ ] If user does not provide a `name`, name from the matching Instrument MUST be used by default — [L353](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L353)
- [ ] Stream configuration `description` SHOULD be used — [L355](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L355)
- [ ] `description` MUST NOT obligate a user to provide one — [L360](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L360)
- [ ] If user does not provide a `description`, description from the matching Instrument MUST be used by default — [L361](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L361)
- [ ] `attribute_keys` allow-list: listed keys MUST be kept, all other attributes MUST be ignored — [L364](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L364)
- [ ] `attribute_keys` MUST NOT obligate a user to provide them — [L372](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L372)
- [ ] If user does not provide `attribute_keys`, SDK SHOULD use the `Attributes` advisory parameter — [L373](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L373)
- [ ] If `Attributes` advisory parameter is absent, all attributes MUST be kept — [L376](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L376)
- [ ] SHOULD support configuring an exclude-list of attribute keys — [L378](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L378)
- [ ] Exclude-list: listed keys MUST be excluded, all other attributes MUST be kept — [L380](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L380)
- [ ] `aggregation` MUST NOT obligate a user to provide one — [L390](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L390)
- [ ] If user does not provide `aggregation`, MeterProvider MUST apply default aggregation configurable per instrument type per MetricReader — [L391](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L391)
- [ ] `exemplar_reservoir` MUST NOT obligate a user to provide one — [L402](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L402)
- [ ] If user does not provide `exemplar_reservoir`, MeterProvider MUST apply a default exemplar reservoir — [L404](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L404)
- [ ] `aggregation_cardinality_limit` MUST NOT obligate a user to provide one — [L412](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L412)
- [ ] If user does not provide `aggregation_cardinality_limit`, MeterProvider MUST apply the default from MetricReader — [L414](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L414)

#### Measurement Processing

- [ ] SDK SHOULD use the specified logic to determine how to process Measurements — [L420](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L420)
- [ ] When no View registered, instrument advisory parameters MUST be honored — [L428](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L428)
- [ ] If applying a View results in conflicting metric identities, SDK SHOULD apply the View and emit a warning — [L439](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L439)
- [ ] If both a View and instrument advisory parameters specify the same aspect, the View MUST take precedence — [L446](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L446)
- [ ] If Instrument could not match any registered Views, SDK SHOULD enable the instrument using default aggregation and temporality — [L448](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L448)

### Aggregation (Stable)

- [ ] SDK MUST provide Drop, Default, Sum, Last Value, Explicit Bucket Histogram aggregations — [L567](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L567)
- [ ] SDK SHOULD provide Base2 Exponential Bucket Histogram aggregation — [L577](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L577)

#### Histogram Aggregations

- [ ] Histogram arithmetic sum SHOULD NOT be collected when used with instruments that record negative measurements — [L646](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L646)

#### Explicit Bucket Histogram Aggregation

- [ ] SDKs SHOULD use the default boundaries when boundaries are not explicitly provided — [L661](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L661)

#### Base2 Exponential Bucket Histogram Aggregation

- [ ] Implementations MUST accept the entire normal range of IEEE floating point values — [L728](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L728)
- [ ] Implementations SHOULD NOT incorporate non-normal values (+Inf, -Inf, NaN) into sum, min, max — [L732](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L732)
- [ ] Implementation MUST maintain reasonable minimum and maximum scale parameters — [L741](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L741)
- [ ] When histogram contains not more than one value, implementation SHOULD use the maximum scale — [L748](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L748)
- [ ] Implementations SHOULD adjust histogram scale to maintain the best resolution possible — [L753](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L753)

### Observations Inside Asynchronous Callbacks (Stable)

- [ ] Callback functions MUST be invoked for the specific MetricReader performing collection — [L762](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L762)
- [ ] Implementation SHOULD disregard async instrument API usage outside of registered callbacks — [L767](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L767)
- [ ] Implementation SHOULD use a timeout to prevent indefinite callback execution — [L770](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L770)
- [ ] Implementation MUST complete execution of all callbacks for a given instrument before starting a subsequent round of collection — [L773](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L773)
- [ ] Implementation SHOULD NOT produce aggregated metric data for a previously-observed attribute set not observed during a successful callback — [L776](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L776)

### Cardinality Limits (Stable)

- [ ] SDKs SHOULD support being configured with a cardinality limit — [L809](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L809)
- [ ] Cardinality limit enforcement SHOULD occur after attribute filtering — [L813](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L813)

#### Configuration

- [ ] If view defines `aggregation_cardinality_limit`, that value SHOULD be used — [L823](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L823)
- [ ] If no matching view but MetricReader defines a default cardinality limit, that value SHOULD be used — [L826](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L826)
- [ ] If no values defined, the default value of 2000 SHOULD be used — [L827](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L827)

#### Overflow Attribute

- [ ] SDK MUST create an Aggregator with the overflow attribute set prior to reaching the cardinality limit — [L837](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L837)
- [ ] SDK MUST provide the guarantee that overflow would not happen if max distinct non-overflow attribute sets is less than or equal to the limit — [L840](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L840)

#### Synchronous Instrument Cardinality Limits

- [ ] Aggregators for synchronous instruments with cumulative temporality MUST continue to export all attribute sets observed prior to overflow — [L846](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L846)
- [ ] SDK MUST ensure every Measurement is reflected in exactly one Aggregator — [L856](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L856)
- [ ] Measurements MUST NOT be double-counted or dropped during an overflow — [L861](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L861)

#### Asynchronous Instrument Cardinality Limits

- [ ] Aggregators of asynchronous instruments SHOULD prefer the first-observed attributes in the callback when limiting cardinality — [L866](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L866)

### Meter (Stable)

- [ ] Distinct meters MUST be treated as separate namespaces for duplicate instrument registration — [L872](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L872)

#### Duplicate Instrument Registration

- [ ] Meter MUST return a functional instrument even for duplicate instrument registrations — [L912](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L912)
- [ ] When duplicate instrument registration occurs (not corrected with a View), a warning SHOULD be emitted — [L919](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L919)
- [ ] Warning SHOULD include information on how to resolve the conflict — [L919](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L919)
- [ ] If conflict involves multiple `description` properties, setting description through a View SHOULD avoid the warning — [L923](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L923)
- [ ] If conflict involves instruments distinguishable by a supported View selector, a renaming View recipe SHOULD be included — [L926](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L926)
- [ ] Otherwise, SDK SHOULD pass through data reporting both Metric objects and emit a generic warning — [L928](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L928)
- [ ] SDK MUST aggregate data from identical Instruments together in its export pipeline — [L942](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L942)

#### Name Conflict

- [ ] When duplicate case-insensitive names occur, Meter MUST return an instrument using the first-seen name and log an error — [L950](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L950)

### Instrument Name

- [ ] Meter SHOULD validate instrument name conforms to syntax — [L962](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L962)
- [ ] If instrument name does not conform, Meter SHOULD emit an error — [L965](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L965)

### Instrument Unit

- [ ] Meter SHOULD NOT validate instrument unit — [L971](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L971)
- [ ] If a unit is not provided or is null, Meter MUST treat it as an empty unit string — [L972](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L972)

### Instrument Description

- [ ] Meter SHOULD NOT validate instrument description — [L977](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L977)
- [ ] If description is not provided or is null, Meter MUST treat it as an empty description string — [L979](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L979)

### Instrument Advisory Parameters (Stable)

- [ ] Meter SHOULD validate instrument advisory parameters — [L985](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L985)
- [ ] If advisory parameter is not valid, Meter SHOULD emit an error and proceed as if the parameter was not provided — [L986](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L986)
- [ ] If multiple identical Instruments have different advisory parameters, Meter MUST return instrument using first-seen advisory parameters and log an error — [L990](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L990)
- [ ] If View and advisory parameters specify the same aspect, View MUST take precedence — [L996](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L996)

#### ExplicitBucketBoundaries Advisory Parameter

- [ ] If no View matches or default aggregation is selected, the ExplicitBucketBoundaries advisory parameter MUST be used — [L1009](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1009)

### Instrument Enabled

- [ ] Synchronous instrument Enabled MUST return false when all resolved views are configured with Drop Aggregation — [L1029](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1029)
- [ ] Otherwise, it SHOULD return true — [L1037](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1037)

### Exemplar (Stable)

- [ ] Metric SDK MUST provide a mechanism to sample Exemplars from measurements via ExemplarFilter and ExemplarReservoir hooks — [L1100](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1100)
- [ ] Exemplar sampling SHOULD be turned on by default — [L1103](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1103)
- [ ] If Exemplar sampling is off, SDK MUST NOT have overhead related to exemplar sampling — [L1104](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1104)
- [ ] Metric SDK MUST allow exemplar sampling to leverage the configuration of metric aggregation — [L1106](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1106)
- [ ] Metric SDK SHOULD provide configuration for Exemplar sampling (ExemplarFilter, ExemplarReservoir) — [L1110](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1110)

#### ExemplarFilter

- [ ] ExemplarFilter configuration MUST allow users to select between built-in ExemplarFilters — [L1117](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1117)
- [ ] ExemplarFilter SHOULD be a configuration parameter of a MeterProvider — [L1122](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1122)
- [ ] Default ExemplarFilter value SHOULD be TraceBased — [L1123](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1123)
- [ ] Filter configuration SHOULD follow the environment variable specification — [L1124](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1124)
- [ ] SDK MUST support AlwaysOn, AlwaysOff, TraceBased filters — [L1126](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1126)

#### ExemplarReservoir

- [ ] ExemplarReservoir interface MUST provide a method to offer measurements and another to collect accumulated Exemplars — [L1148](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1148)
- [ ] A new ExemplarReservoir MUST be created for every known timeseries data point — [L1151](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1151)
- [ ] "offer" method SHOULD accept measurements including value, attributes, context, timestamp — [L1155](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1155)
- [ ] "offer" method SHOULD have ability to pull associated trace/span information without full context — [L1164](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1164)
- [ ] If filtered subset of Attributes is accepted, this MUST be clearly documented and reservoir MUST be given the timeseries Attributes at construction — [L1172](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1172)
- [ ] "collect" method MUST return accumulated Exemplars — [L1179](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1179)
- [ ] Exemplars reported against a metric data point SHOULD have occurred within the start/stop timestamps of that point — [L1181](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1181)
- [ ] Exemplars MUST retain any attributes available in the measurement not preserved by aggregation or view configuration — [L1186](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1186)
- [ ] ExemplarReservoir SHOULD avoid allocations when sampling exemplars — [L1192](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1192)

#### Exemplar Defaults

- [ ] SDK MUST include SimpleFixedSizeExemplarReservoir and AlignedHistogramBucketExemplarReservoir — [L1196](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1196)
- [ ] Explicit bucket histogram with more than 1 bucket SHOULD use AlignedHistogramBucketExemplarReservoir — [L1203](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1203)
- [ ] Base2 Exponential Histogram SHOULD use SimpleFixedSizeExemplarReservoir with reservoir = min(20, max_buckets) — [L1205](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1205)
- [ ] All other aggregations SHOULD use SimpleFixedSizeExemplarReservoir — [L1209](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1209)

#### SimpleFixedSizeExemplarReservoir

- [ ] MUST use uniformly-weighted sampling algorithm based on number of samples seen — [L1218](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1218)
- [ ] Any stateful portion of sampling computation SHOULD be reset every collection cycle — [L1235](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1235)
- [ ] If no size configuration provided, a default size of 1 SHOULD be used — [L1242](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1242)

#### AlignedHistogramBucketExemplarReservoir

- [ ] MUST take a configuration parameter that is the configuration of a Histogram — [L1246](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1246)
- [ ] MUST store at most one measurement per histogram bucket — [L1247](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1247)
- [ ] SHOULD use uniformly-weighted sampling to determine if offered measurements should be sampled — [L1248](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1248)
- [ ] Configuration parameter for bucket boundaries SHOULD have the same format as specifying Explicit Bucket Histogram boundaries — [L1276](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1276)

#### Custom ExemplarReservoir

- [ ] SDK MUST provide a mechanism for SDK users to provide their own ExemplarReservoir implementation — [L1282](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1282)
- [ ] Extension MUST be configurable on a metric View — [L1283](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1283)
- [ ] Individual reservoirs MUST still be instantiated per metric-timeseries — [L1284](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1284)

### MetricReader (Stable)

- [ ] MetricReader construction SHOULD be provided with an exporter — [L1302](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1302)
- [ ] Default output aggregation function SHOULD be obtained from the exporter; if not configured, default aggregation SHOULD be used — [L1305](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1305)
- [ ] Output temporality function SHOULD be obtained from the exporter; if not configured, Cumulative temporality SHOULD be used — [L1306](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1306)
- [ ] Default cardinality limit, if not configured, a default value of 2000 SHOULD be used — [L1307](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1307)
- [ ] A common implementation, periodic exporting MetricReader, SHOULD be provided — [L1318](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1318)
- [ ] MetricReader MUST ensure data points from OTel instruments are output in the configured aggregation temporality — [L1321](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1321)
- [ ] For synchronous instruments with Cumulative temporality, Collect MUST receive data points exposed in previous collections — [L1339](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1339)
- [ ] For synchronous instruments with Delta temporality, Collect MUST only receive data points with measurements recorded since the previous collection — [L1342](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1342)
- [ ] For asynchronous instruments with Delta or Cumulative temporality, Collect MUST only receive data points with measurements recorded since previous collection — [L1345](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1345)
- [ ] For Cumulative temporality, successive data points MUST repeat the same starting timestamps — [L1354](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1354)
- [ ] For Delta temporality, successive data points MUST advance the starting timestamp — [L1357](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1357)
- [ ] Ending timestamp MUST always be equal to time the metric data point took effect (when Collect was invoked) — [L1359](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1359)
- [ ] SDK MUST support multiple MetricReader instances on the same MeterProvider — [L1365](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1365)
- [ ] Collect on one MetricReader SHOULD NOT introduce side-effects to other MetricReader instances — [L1367](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1367)
- [ ] SDK MUST NOT allow a MetricReader instance to be registered on more than one MeterProvider — [L1374](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1374)
- [ ] SDK SHOULD provide a way to allow MetricReader to respond to ForceFlush and Shutdown — [L1391](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1391)

#### Collect

- [ ] Collect SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1406](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1406)
- [ ] Collect SHOULD invoke Produce on registered MetricProducers — [L1416](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1416)

#### Shutdown

- [ ] Shutdown MUST be called only once for each MetricReader instance — [L1430](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1430)
- [ ] After Shutdown, subsequent Collect invocations are not allowed; SDKs SHOULD return failure — [L1431](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1431)
- [ ] Shutdown SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1434](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1434)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L1437](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1437)

### Periodic Exporting MetricReader

- [ ] Reader MUST synchronize calls to MetricExporter's Export to make sure they are not invoked concurrently — [L1455](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1455)

#### ForceFlush (Periodic)

- [ ] ForceFlush SHOULD collect metrics, call Export(batch) and ForceFlush() on the configured Push Metric Exporter — [L1478](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1478)
- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1482](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1482)
- [ ] ForceFlush SHOULD return ERROR status if there is an error condition — [L1483](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1483)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L1488](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1488)

### MetricExporter (Stable)

- [ ] MetricExporter defines the interface that protocol-specific exporters MUST implement — [L1496](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1496)
- [ ] Metric Exporters SHOULD report an error for unsupported Aggregation or Aggregation Temporality — [L1512](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1512)

#### Push Metric Exporter

- [ ] Push Metric Exporter MUST support Export(batch), ForceFlush, Shutdown functions — [L1557](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1557)

##### Export(batch)

- [ ] SDK MUST provide a way for exporter to get Meter information associated with each Metric Point — [L1565](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1565)
- [ ] Export MUST NOT block indefinitely; there MUST be a reasonable upper limit timeout — [L1571](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1571)
- [ ] Default SDK SHOULD NOT implement retry logic — [L1575](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1575)

##### ForceFlush (Exporter)

- [ ] ForceFlush SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1629](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1629)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L1636](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1636)

##### Shutdown (Exporter)

- [ ] Shutdown SHOULD be called only once for each MetricExporter instance — [L1646](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1646)
- [ ] After Shutdown, subsequent Export calls should return Failure — [L1647](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1647)
- [ ] Shutdown SHOULD NOT block indefinitely — [L1650](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1650)

### MetricProducer (Stable)

- [ ] MetricProducer defines the interface which bridges to third-party metric sources MUST implement — [L1707](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1707)
- [ ] MetricProducer implementations SHOULD accept configuration for AggregationTemporality — [L1711](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1711)
- [ ] MetricProducer MUST support the Produce function — [L1735](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1735)
- [ ] Produce MUST return a batch of Metric Points — [L1740](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1740)
- [ ] If batch includes resource information, Produce SHOULD require a resource as a parameter — [L1746](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1746)
- [ ] Produce SHOULD provide a way to let the caller know whether it succeeded, failed or timed out — [L1751](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1751)
- [ ] If batch can include InstrumentationScope, Produce SHOULD include a single InstrumentationScope identifying the MetricProducer — [L1758](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1758)

### Defaults and Configuration

- [ ] SDK MUST provide configuration according to the SDK environment variables specification — [L1837](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1837)

### Numerical Limits Handling

- [ ] SDK MUST handle numerical limits in a graceful way — [L1842](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1842)
- [ ] If SDK receives float/double values, it MUST handle all possible values (e.g. NaN, Infinities) — [L1845](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1845)

### Compatibility Requirements (Stable)

- [ ] All metrics components SHOULD allow new methods to be added without introducing breaking changes — [L1862](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1862)
- [ ] All metrics SDK methods SHOULD allow optional parameters to be added without introducing breaking changes — [L1865](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1865)

### Concurrency Requirements (Stable)

- [ ] MeterProvider: Meter creation, ForceFlush, and Shutdown MUST be safe to be called concurrently — [L1875](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1875)
- [ ] ExemplarReservoir: all methods MUST be safe to be called concurrently — [L1878](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1878)
- [ ] MetricReader: Collect, ForceFlush, and Shutdown MUST be safe to be called concurrently — [L1880](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1880)
- [ ] MetricExporter: ForceFlush and Shutdown MUST be safe to be called concurrently — [L1883](references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L1883)

---

## Metrics Exporters

### Console (stdout)

> Ref: [metrics/sdk_exporters/stdout.md](references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md)

- [ ] Documentation SHOULD warn users about unspecified output format — [L14](references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md#L14)
- [ ] Stdout Metrics Exporter MUST provide configuration to set MetricReader output temporality as a function of instrument kind — [L30](references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md#L30)
- [ ] Temporality option MUST set temporality to Cumulative for all instrument kinds by default — [L33](references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md#L33)
- [ ] If default_aggregation is provided, it MUST use the default aggregation by default — [L37](references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md#L37)
- [ ] If auto-configuration mechanism is provided, exporter MUST be paired with a periodic exporting MetricReader with default exportIntervalMilliseconds of 10000 — [L44](references/opentelemetry-specification/v1.55.0/metrics/sdk_exporters/stdout.md#L44)

## Logs API

> Ref: [logs/api.md](references/opentelemetry-specification/v1.55.0/logs/api.md)

### LoggerProvider
- [ ] API SHOULD provide a way to set/register and access a global default LoggerProvider — [L59](references/opentelemetry-specification/v1.55.0/logs/api.md#L59)
- [ ] LoggerProvider MUST provide Get a Logger function — [L64](references/opentelemetry-specification/v1.55.0/logs/api.md#L64)

### Get a Logger
- [ ] API MUST accept `name` parameter (instrumentation scope) — [L70](references/opentelemetry-specification/v1.55.0/logs/api.md#L70)
- [ ] API MUST accept optional `version` parameter — [L85](references/opentelemetry-specification/v1.55.0/logs/api.md#L85)
- [ ] API MUST accept optional `schema_url` parameter — [L88](references/opentelemetry-specification/v1.55.0/logs/api.md#L88)
- [ ] API MUST accept optional `attributes` parameter, structured for variable number including none — [L92](references/opentelemetry-specification/v1.55.0/logs/api.md#L92)

### Logger
- [ ] Logger MUST provide function to Emit a LogRecord — [L103](references/opentelemetry-specification/v1.55.0/logs/api.md#L103)
- [ ] Logger SHOULD provide function to report if Enabled — [L107](references/opentelemetry-specification/v1.55.0/logs/api.md#L107)

### Emit a LogRecord
- [ ] API MUST accept Timestamp (optional) — [L117](references/opentelemetry-specification/v1.55.0/logs/api.md#L117)
- [ ] API MUST accept Observed Timestamp (optional) — [L118](references/opentelemetry-specification/v1.55.0/logs/api.md#L118)
- [ ] API MUST accept Context; if implicit supported SHOULD be optional, MUST use current if unspecified — [L119](references/opentelemetry-specification/v1.55.0/logs/api.md#L119)
- [ ] When only explicit Context supported, parameter SHOULD be required — [L122](references/opentelemetry-specification/v1.55.0/logs/api.md#L122)
- [ ] API MUST accept Severity Number (optional) — [L123](references/opentelemetry-specification/v1.55.0/logs/api.md#L123)
- [ ] API MUST accept Severity Text (optional) — [L124](references/opentelemetry-specification/v1.55.0/logs/api.md#L124)
- [ ] API MUST accept Body (optional) — [L125](references/opentelemetry-specification/v1.55.0/logs/api.md#L125)
- [ ] API MUST accept Attributes (optional) — [L126](references/opentelemetry-specification/v1.55.0/logs/api.md#L126)
- [ ] API MUST accept Event Name (optional) — [L127](references/opentelemetry-specification/v1.55.0/logs/api.md#L127)

### Enabled
- [ ] Logger SHOULD provide Enabled API — [L135](references/opentelemetry-specification/v1.55.0/logs/api.md#L135)
- [ ] Enabled API SHOULD accept Context parameter (optional if implicit supported, MUST use current if unspecified) — [L140](references/opentelemetry-specification/v1.55.0/logs/api.md#L140)
- [ ] When only explicit Context, accepting Context parameter is REQUIRED — [L143](references/opentelemetry-specification/v1.55.0/logs/api.md#L143)
- [ ] Enabled API SHOULD accept Severity Number (optional) — [L144](references/opentelemetry-specification/v1.55.0/logs/api.md#
Now I have all 11 files read. Let me compile the complete compliance checklist.

## Common

> Ref: [common/README.md](references/opentelemetry-specification/v1.55.0/common/README.md)

### AnyValue
- [ ] A homogeneous array MUST NOT contain values of different types — [L46](references/opentelemetry-specification/v1.55.0/common/README.md#L46)
- [ ] AnyValues expressing empty value, zero, empty string, or empty array MUST be stored and passed on to processors/exporters — [L60](references/opentelemetry-specification/v1.55.0/common/README.md#L60)
- [ ] `null` values within arrays MUST be preserved as-is (passed on to processors/exporters as `null`) — [L67](references/opentelemetry-specification/v1.55.0/common/README.md#L67)
- [ ] APIs SHOULD be documented that using array and map values may carry higher performance overhead — [L56](references/opentelemetry-specification/v1.55.0/common/README.md#L56)
- [ ] `null` use within homogeneous arrays SHOULD generally be avoided unless language constraints make this impossible — [L64](references/opentelemetry-specification/v1.55.0/common/README.md#L64)

### map<string, AnyValue>
- [ ] Case sensitivity of keys MUST be preserved — [L80](references/opentelemetry-specification/v1.55.0/common/README.md#L80)
- [ ] Implementation MUST by default enforce that exported maps contain only unique keys — [L85](references/opentelemetry-specification/v1.55.0/common/README.md#L85)
- [ ] If option to allow duplicate keys is provided, it MUST be documented that handling of maps with duplicate keys is unpredictable — [L93](references/opentelemetry-specification/v1.55.0/common/README.md#L93)

### AnyValue Representation for non-OTLP Protocols
- [ ] Values SHOULD be represented as strings following encoding rules — [L103](references/opentelemetry-specification/v1.55.0/common/README.md#L103)
- [ ] Strings SHOULD be represented as-is without additional encoding — [L113](references/opentelemetry-specification/v1.55.0/common/README.md#L113)
- [ ] Strings SHOULD NOT be encoded as JSON strings (with surrounding quotes) — [L114](references/opentelemetry-specification/v1.55.0/common/README.md#L114)
- [ ] Booleans SHOULD be represented as JSON booleans — [L120](references/opentelemetry-specification/v1.55.0/common/README.md#L120)
- [ ] Integers SHOULD be represented as JSON numbers — [L127](references/opentelemetry-specification/v1.55.0/common/README.md#L127)
- [ ] Floating point numbers SHOULD be represented as JSON numbers — [L134](references/opentelemetry-specification/v1.55.0/common/README.md#L134)
- [ ] Special floating point values NaN/Infinity SHOULD be represented as `NaN`, `Infinity`, `-Infinity` — [L137](references/opentelemetry-specification/v1.55.0/common/README.md#L137)
- [ ] Special floats SHOULD NOT be encoded as JSON strings (with surrounding quotes) — [L139](references/opentelemetry-specification/v1.55.0/common/README.md#L139)
- [ ] Byte arrays SHOULD be Base64-encoded — [L145](references/opentelemetry-specification/v1.55.0/common/README.md#L145)
- [ ] Byte arrays SHOULD NOT be encoded as JSON strings (with surrounding quotes) — [L146](references/opentelemetry-specification/v1.55.0/common/README.md#L146)
- [ ] Empty values SHOULD be represented as the empty string — [L152](references/opentelemetry-specification/v1.55.0/common/README.md#L152)
- [ ] Empty values SHOULD NOT be encoded as JSON string (with surrounding quotes) — [L153](references/opentelemetry-specification/v1.55.0/common/README.md#L153)
- [ ] Arrays (except byte arrays) SHOULD be represented as JSON arrays — [L157](references/opentelemetry-specification/v1.55.0/common/README.md#L157)
- [ ] Nested byte arrays SHOULD be represented as Base64-encoded JSON strings — [L159](references/opentelemetry-specification/v1.55.0/common/README.md#L159)
- [ ] Nested empty values in arrays SHOULD be represented as JSON null — [L161](references/opentelemetry-specification/v1.55.0/common/README.md#L161)
- [ ] NaN/Infinity in arrays SHOULD be represented as JSON strings — [L162](references/opentelemetry-specification/v1.55.0/common/README.md#L162)
- [ ] Maps SHOULD be represented as JSON objects — [L169](references/opentelemetry-specification/v1.55.0/common/README.md#L169)
- [ ] Nested byte arrays in maps SHOULD be represented as Base64-encoded JSON strings — [L171](references/opentelemetry-specification/v1.55.0/common/README.md#L171)
- [ ] Nested empty values in maps SHOULD be represented as JSON null — [L173](references/opentelemetry-specification/v1.55.0/common/README.md#L173)
- [ ] NaN/Infinity in maps SHOULD be represented as JSON strings — [L174](references/opentelemetry-specification/v1.55.0/common/README.md#L174)

### Attribute
- [ ] Attribute MUST have key-value pair properties — [L183](references/opentelemetry-specification/v1.55.0/common/README.md#L183)
- [ ] Attribute key MUST be a non-`null` and non-empty string — [L185](references/opentelemetry-specification/v1.55.0/common/README.md#L185)
- [ ] Attribute value MUST be one of types defined in AnyValue — [L187](references/opentelemetry-specification/v1.55.0/common/README.md#L187)

### Attribute Collections
- [ ] Implementation MUST by default enforce that exported attribute collections contain only unique keys — [L215](references/opentelemetry-specification/v1.55.0/common/README.md#L215)
- [ ] Setting an attribute with the same key as existing SHOULD overwrite the existing attribute's value — [L223](references/opentelemetry-specification/v1.55.0/common/README.md#L223)
- [ ] If option to allow duplicate keys is provided, it MUST be documented that handling is unpredictable — [L242](references/opentelemetry-specification/v1.55.0/common/README.md#L242)

### Attribute Limits
- [ ] By default an SDK SHOULD apply truncation as per configurable parameters — [L255](references/opentelemetry-specification/v1.55.0/common/README.md#L255)
- [ ] If string attribute exceeds length limit, SDKs MUST truncate that value — [L263](references/opentelemetry-specification/v1.55.0/common/README.md#L263)
- [ ] If byte array exceeds length limit, SDKs MUST truncate that value — [L267](references/opentelemetry-specification/v1.55.0/common/README.md#L267)
- [ ] For array of AnyValue, apply limit to each element separately (and recursively) — [L271](references/opentelemetry-specification/v1.55.0/common/README.md#L271)
- [ ] For map, apply limit to each value separately (and recursively) — [L273](references/opentelemetry-specification/v1.55.0/common/README.md#L273)
- [ ] Otherwise a value MUST NOT be truncated — [L274](references/opentelemetry-specification/v1.55.0/common/README.md#L274)
- [ ] If adding attribute exceeds count limit, SDK MUST discard that attribute — [L278](references/opentelemetry-specification/v1.55.0/common/README.md#L278)
- [ ] Otherwise an attribute MUST NOT be discarded — [L282](references/opentelemetry-specification/v1.55.0/common/README.md#L282)
- [ ] Log to indicate truncated/discarded attribute MUST NOT be emitted more than once per record — [L285](references/opentelemetry-specification/v1.55.0/common/README.md#L285)
- [ ] If SDK implements limits, it MUST provide a way to change limits programmatically — [L288](references/opentelemetry-specification/v1.55.0/common/README.md#L288)
- [ ] Names of configuration options SHOULD be the same as in the configurable parameters list — [L289](references/opentelemetry-specification/v1.55.0/common/README.md#L289)
- [ ] If both general and model-specific limit are implemented, SDK MUST first attempt model-specific, then general, then model-specific default, then global default — [L294](references/opentelemetry-specification/v1.55.0/common/README.md#L294)
- [ ] Resource attributes SHOULD be exempt from attribute limits — [L310](references/opentelemetry-specification/v1.55.0/common/README.md#L310)

## Context

> Ref: [context/README.md](references/opentelemetry-specification/v1.55.0/context/README.md)

- [ ] Context MUST be immutable, write operations MUST result in creation of a new Context — [L37](references/opentelemetry-specification/v1.55.0/context/README.md#L37)
- [ ] OpenTelemetry MUST provide its own Context implementation when no clear pre-existing option is available — [L43](references/opentelemetry-specification/v1.55.0/context/README.md#L43)

### Create a Key
- [ ] API MUST accept key name parameter — [L65](references/opentelemetry-specification/v1.55.0/context/README.md#L65)
- [ ] Multiple calls to CreateKey with same name SHOULD NOT return the same value unless language constraints dictate otherwise — [L65](references/opentelemetry-specification/v1.55.0/context/README.md#L65)
- [ ] API MUST return an opaque object representing the newly created key — [L67](references/opentelemetry-specification/v1.55.0/context/README.md#L67)

### Get Value
- [ ] API MUST accept Context and key parameters — [L74](references/opentelemetry-specification/v1.55.0/context/README.md#L74)
- [ ] API MUST return the value in the Context for the specified key — [L79](references/opentelemetry-specification/v1.55.0/context/README.md#L79)

### Set Value
- [ ] API MUST accept Context, key, and value parameters — [L86](references/opentelemetry-specification/v1.55.0/context/README.md#L86)
- [ ] API MUST return a new Context containing the new value — [L92](references/opentelemetry-specification/v1.55.0/context/README.md#L92)

### Optional Global Operations
- [ ] These operations SHOULD only be used to implement automatic scope switching and define higher level APIs — [L98](references/opentelemetry-specification/v1.55.0/context/README.md#L98)
- [ ] Get current Context: API MUST return the Context associated with the caller's current execution unit — [L103](references/opentelemetry-specification/v1.55.0/context/README.md#L103)
- [ ] Attach Context: API MUST accept Context parameter — [L109](references/opentelemetry-specification/v1.55.0/context/README.md#L109)
- [ ] Attach Context: API MUST return a value that can be used as Token to restore previous Context — [L113](references/opentelemetry-specification/v1.55.0/context/README.md#L113)
- [ ] Detach Context: API MUST accept a Token parameter — [L133](references/opentelemetry-specification/v1.55.0/context/README.md#L133)

## API Propagators

> Ref: [context/api-propagators.md](references/opentelemetry-specification/v1.55.0/context/api-propagators.md)

### Propagator Types
- [ ] Propagators MUST define Inject and Extract operations — [L83](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L83)
- [ ] Each Propagator type MUST define the specific carrier type — [L84](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L84)

### Inject
- [ ] Propagator MUST retrieve the appropriate value from the Context first — [L93](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L93)

### Extract
- [ ] Implementation MUST NOT throw an exception and MUST NOT store a new value in Context if value cannot be parsed — [L102](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L102)

### TextMap Propagator
- [ ] Key/value pairs MUST only consist of US-ASCII characters that make up valid HTTP header fields — [L122](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L122)
- [ ] Getter and Setter MUST be stateless and allowed to be saved as constants — [L130](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L130)

### Setter - Set
- [ ] Implementation SHOULD preserve casing if protocol is case insensitive, otherwise MUST preserve casing — [L183](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L183)

### Getter - Keys
- [ ] Keys function MUST return the list of all keys in the carrier — [L209](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L209)

### Getter - Get
- [ ] Get function MUST return the first value of the given propagation key or return null — [L223](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L223)
- [ ] If getter is intended to work with HTTP request, getter MUST be case insensitive — [L230](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L230)

### Getter - GetAll
- [ ] If explicitly implemented, GetAll MUST return all values of the given propagation key — [L240](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L240)
- [ ] GetAll SHOULD return values in the same order as they appear in the carrier — [L241](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L241)
- [ ] If key doesn't exist, GetAll SHOULD return an empty collection — [L242](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L242)
- [ ] If getter is intended to work with HTTP request, getter MUST be case insensitive — [L249](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L249)

### Composite Propagator
- [ ] Implementations MUST offer a facility to group multiple Propagators as a single entity — [L261](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L261)
- [ ] There MUST be functions to create, extract, and inject composite propagators — [L272](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L272)

### Global Propagators
- [ ] OpenTelemetry API MUST provide a way to obtain a propagator for each supported type — [L310](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L310)
- [ ] Instrumentation libraries SHOULD call propagators to extract and inject context on all remote calls — [L311](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L311)
- [ ] OpenTelemetry API MUST use no-op propagators unless explicitly configured otherwise — [L322](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L322)
- [ ] If pre-configured, Propagators SHOULD default to composite containing W3C Trace Context and Baggage propagators — [L329](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L329)
- [ ] Pre-configured propagators MUST also allow being disabled or overridden — [L332](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L332)
- [ ] Get Global Propagator: method MUST exist for each supported Propagator type — [L336](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L336)
- [ ] Set Global Propagator: method MUST exist for each supported Propagator type — [L342](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L342)

### Propagators Distribution
- [ ] W3C TraceContext and W3C Baggage MUST be maintained and distributed as extension packages — [L352](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L352)
- [ ] Additional propagators implementing vendor-specific protocols MUST NOT be maintained in Core OpenTelemetry repos — [L378](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L378)

### W3C Trace Context Requirements
- [ ] W3C propagator MUST parse and validate `traceparent` and `tracestate` per W3C Trace Context Level 2 — [L383](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L383)
- [ ] W3C propagator MUST propagate a valid `traceparent` using same header — [L383](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L383)
- [ ] W3C propagator MUST propagate a valid `tracestate` unless value is empty — [L383](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L383)

### B3 Requirements
- [ ] B3 Extract MUST attempt to extract using single and multi-header formats — [L404](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L404)
- [ ] B3 Extract MUST preserve debug trace flag and propagate it; MUST set sampled flag when debug is set — [L407](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L407)
- [ ] B3 Extract MUST NOT reuse X-B3-SpanId as server-side span id — [L410](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L410)
- [ ] B3 Inject MUST default to single-header format — [L416](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L416)
- [ ] B3 Inject MUST provide configuration to change default to multi-header — [L417](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L417)
- [ ] B3 Inject MUST NOT propagate X-B3-ParentSpanId — [L419](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L419)
- [ ] B3 Fields MUST return header names that correspond to configured format — [L424](references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L424)

## Baggage

> Ref: [baggage/api.md](references/opentelemetry-specification/v1.55.0/baggage/api.md)

### Overview
- [ ] Each name in Baggage MUST be associated with exactly one value — [L38](references/opentelemetry-specification/v1.55.0/baggage/api.md#L38)
- [ ] Language API SHOULD NOT restrict which strings are used as baggage names — [L43](references/opentelemetry-specification/v1.55.0/baggage/api.md#L43)
- [ ] Language API MUST accept any valid UTF-8 string as baggage value and return same from Get — [L53](references/opentelemetry-specification/v1.55.0/baggage/api.md#L53)
- [ ] Language API MUST treat both baggage names and values as case sensitive — [L57](references/opentelemetry-specification/v1.55.0/baggage/api.md#L57)
- [ ] Baggage API MUST be fully functional in the absence of an installed SDK — [L79](references/opentelemetry-specification/v1.55.0/baggage/api.md#L79)
- [ ] Baggage container MUST be immutable — [L84](references/opentelemetry-specification/v1.55.0/baggage/api.md#L84)

### Get Value
- [ ] Baggage API MUST provide a function that takes name and returns value or null — [L92](references/opentelemetry-specification/v1.55.0/baggage/api.md#L92)

### Get All Values
- [ ] Order of name/value pairs MUST NOT be significant — [L102](references/opentelemetry-specification/v1.55.0/baggage/api.md#L102)

### Set Value
- [ ] Baggage API MUST provide a function which takes name and value and returns new Baggage — [L108](references/opentelemetry-specification/v1.55.0/baggage/api.md#L108)

### Remove Value
- [ ] Baggage API MUST provide a function which takes name and returns new Baggage without it — [L128](references/opentelemetry-specification/v1.55.0/baggage/api.md#L128)

### Context Interaction
- [ ] If not operating directly on Context, MUST provide extract Baggage from Context and insert Baggage to Context — [L144](references/opentelemetry-specification/v1.55.0/baggage/api.md#L144)
- [ ] API users SHOULD NOT have access to the Context Key used by Baggage API — [L149](references/opentelemetry-specification/v1.55.0/baggage/api.md#L149)
- [ ] If implicit Context supported, API SHOULD provide get/set currently active Baggage — [L154](references/opentelemetry-specification/v1.55.0/baggage/api.md#L154)
- [ ] Functionality SHOULD be fully implemented in the API when possible — [L166](references/opentelemetry-specification/v1.55.0/baggage/api.md#L166)

### Clear Baggage
- [ ] Baggage API MUST provide a way to remove all baggage entries from a context — [L172](references/opentelemetry-specification/v1.55.0/baggage/api.md#L172)

### Propagation
- [ ] API layer or extension package MUST include a TextMapPropagator implementing W3C Baggage Specification — [L184](references/opentelemetry-specification/v1.55.0/baggage/api.md#L184)

### Conflict Resolution
- [ ] If new name/value pair has same name as existing, new pair MUST take precedence — [L207](references/opentelemetry-specification/v1.55.0/baggage/api.md#L207)

## Resource

> Ref: [resource/sdk.md](references/opentelemetry-specification/v1.55.0/resource/sdk.md)

- [ ] SDK MUST allow for creation of Resources and for associating them with telemetry — [L22](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L22)
- [ ] All Spans produced by any Tracer from the provider MUST be associated with this Resource — [L29](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L29)

### SDK-provided Resource Attributes
- [ ] SDK MUST provide access to a Resource with at least the attributes listed at Semantic Attributes with SDK-provided Default Value — [L39](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L39)
- [ ] This resource MUST be associated with TracerProvider or MeterProvider if another resource was not explicitly specified — [L41](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L41)

### Create
- [ ] Interface MUST provide a way to create a new resource from Attributes — [L58](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L58)

### Merge
- [ ] Interface MUST provide a way for old and updating resource to be merged into new resource — [L71](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L71)
- [ ] Resulting resource MUST have all attributes from both input resources — [L78](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L78)
- [ ] If key exists on both, value of updating resource MUST be picked — [L79](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L79)

### Detecting Resource Information
- [ ] Custom resource detectors for generic platforms MUST be implemented as packages separate from SDK — [L107](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L107)
- [ ] Resource detector packages MUST provide a method that returns a resource — [L110](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L110)
- [ ] Failure to detect resource information MUST NOT be considered an error — [L122](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L122)
- [ ] Error during detection attempt SHOULD be considered an error — [L123](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L123)
- [ ] Resource detectors populating semantic conventions MUST ensure Schema URL matches — [L127](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L127)
- [ ] Empty Schema URL SHOULD be used if detector doesn't populate known attributes — [L128](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L128)
- [ ] If multiple detectors use different non-empty Schema URLs it MUST be an error — [L133](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L133)

### Environment Variable Resource
- [ ] SDK MUST extract information from OTEL_RESOURCE_ATTRIBUTES and merge as secondary resource — [L179](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L179)
- [ ] All attribute values MUST be considered strings — [L186](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L186)
- [ ] `,` and `=` characters in keys and values MUST be percent encoded — [L187](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L187)
- [ ] In case of error, entire env var value SHOULD be discarded and error SHOULD be reported — [L192](references/opentelemetry-specification/v1.55.0/resource/sdk.md#L192)

## Logs API

> Ref: [logs/api.md](references/opentelemetry-specification/v1.55.0/logs/api.md)

### LoggerProvider
- [ ] API SHOULD provide a way to set/register and access a global default LoggerProvider — [L59](references/opentelemetry-specification/v1.55.0/logs/api.md#L59)
- [ ] LoggerProvider MUST provide Get a Logger function — [L64](references/opentelemetry-specification/v1.55.0/logs/api.md#L64)

### Get a Logger
- [ ] API MUST accept `name` parameter (instrumentation scope) — [L70](references/opentelemetry-specification/v1.55.0/logs/api.md#L70)
- [ ] API MUST accept optional `version` parameter — [L85](references/opentelemetry-specification/v1.55.0/logs/api.md#L85)
- [ ] API MUST accept optional `schema_url` parameter — [L88](references/opentelemetry-specification/v1.55.0/logs/api.md#L88)
- [ ] API MUST accept optional `attributes` parameter, structured to accept variable number — [L92](references/opentelemetry-specification/v1.55.0/logs/api.md#L92)

### Logger
- [ ] Logger MUST provide a function to Emit a LogRecord — [L103](references/opentelemetry-specification/v1.55.0/logs/api.md#L103)
- [ ] Logger SHOULD provide Enabled function — [L107](references/opentelemetry-specification/v1.55.0/logs/api.md#L107)

### Emit a LogRecord
- [ ] API MUST accept Timestamp (optional), Observed Timestamp (optional), Context, Severity Number (optional), Severity Text (optional), Body (optional), Attributes (optional), Event Name (optional) — [L115](references/opentelemetry-specification/v1.55.0/logs/api.md#L115)
- [ ] When implicit Context is supported, Context parameter SHOULD be optional and if unspecified MUST use current Context — [L120](references/opentelemetry-specification/v1.55.0/logs/api.md#L120)
- [ ] When only explicit Context is supported, Context parameter SHOULD be required — [L122](references/opentelemetry-specification/v1.55.0/logs/api.md#L122)

### Enabled
- [ ] Enabled API SHOULD accept Context, Severity Number (optional), Event Name (optional) — [L139](references/opentelemetry-specification/v1.55.0/logs/api.md#L139)
- [ ] When implicit Context supported, Context parameter SHOULD be optional, if unspecified MUST use current Context — [L141](references/opentelemetry-specification/v1.55.0/logs/api.md#L141)
- [ ] When only explicit Context supported, accepting Context parameter is REQUIRED — [L143](references/opentelemetry-specification/v1.55.0/logs/api.md#L143)
- [ ] Enabled MUST return a language idiomatic boolean type — [L147](references/opentelemetry-specification/v1.55.0/logs/api.md#L147)
- [ ] API SHOULD be documented that authors need to call each time they emit a LogRecord — [L152](references/opentelemetry-specification/v1.55.0/logs/api.md#L152)

### Optional and Required Parameters
- [ ] For each optional parameter, API MUST be structured to accept it but MUST NOT obligate user to provide it — [L161](references/opentelemetry-specification/v1.55.0/logs/api.md#L161)
- [ ] For each required parameter, API MUST be structured to obligate user to provide it — [L164](references/opentelemetry-specification/v1.55.0/logs/api.md#L164)

### Concurrency Requirements
- [ ] LoggerProvider: all methods MUST be documented as safe for concurrent use — [L172](references/opentelemetry-specification/v1.55.0/logs/api.md#L172)
- [ ] Logger: all methods MUST be documented as safe for concurrent use — [L175](references/opentelemetry-specification/v1.55.0/logs/api.md#L175)

## Logs SDK

> Ref: [logs/sdk.md](references/opentelemetry-specification/v1.55.0/logs/sdk.md)

### LoggerProvider
- [ ] All language implementations MUST provide an SDK — [L55](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L55)
- [ ] LoggerProvider MUST provide a way to allow a Resource to be specified — [L59](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L59)
- [ ] If Resource is specified, it SHOULD be associated with all LogRecords produced — [L60](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L60)

### LoggerProvider Creation
- [ ] SDK SHOULD allow creation of multiple independent LoggerProviders — [L65](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L65)

### Logger Creation
- [ ] It SHOULD only be possible to create Logger instances through a LoggerProvider — [L69](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L69)
- [ ] LoggerProvider MUST implement the Get a Logger API — [L72](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L72)
- [ ] Input provided by user MUST be used to create InstrumentationScope stored on Logger — [L74](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L74)
- [ ] If invalid name, a working Logger MUST be returned as fallback — [L79](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L79)
- [ ] Invalid name SHOULD keep the original invalid value — [L80](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L80)
- [ ] A message reporting invalid value SHOULD be logged — [L81](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L81)

### Configuration
- [ ] Configuration (LogRecordProcessors) MUST be owned by LoggerProvider — [L92](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L92)
- [ ] If configuration is updated, it MUST also apply to all already returned Loggers — [L97](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L97)

### Shutdown
- [ ] Shutdown MUST be called only once for each LoggerProvider instance — [L140](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L140)
- [ ] After Shutdown, subsequent attempts to get Logger are not allowed; SDKs SHOULD return no-op Logger — [L141](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L141)
- [ ] Shutdown SHOULD provide a way to let caller know success/failure/timeout — [L144](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L144)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L147](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L147)
- [ ] Shutdown MUST be implemented by invoking Shutdown on all registered LogRecordProcessors — [L152](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L152)

### ForceFlush
- [ ] ForceFlush SHOULD provide a way to let caller know success/failure/timeout — [L163](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L163)
- [ ] ForceFlush SHOULD return ERROR status on error, NO ERROR otherwise — [L163](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L163)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L168](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L168)
- [ ] ForceFlush MUST invoke ForceFlush on all registered LogRecordProcessors — [L172](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L172)

### Emit a LogRecord (SDK)
- [ ] If Observed Timestamp is unspecified, implementation SHOULD set it equal to current time — [L226](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L226)
- [ ] If Exception is provided, SDK MUST by default set attributes from exception with semantic conventions — [L228](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L228)
- [ ] User-provided attributes MUST take precedence and MUST NOT be overwritten by exception-derived attributes — [L231](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L231)

### Enabled (SDK)
- [ ] Enabled MUST return false when there are no registered LogRecordProcessors — [L256](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L256)
- [ ] Enabled MUST return false when all registered processors implement Enabled and each returns false — [L267](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L267)
- [ ] Otherwise, Enabled SHOULD return true — [L270](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L270)

### ReadableLogRecord
- [ ] A function receiving ReadableLogRecord MUST be able to access all information added to the LogRecord — [L279](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L279)
- [ ] ReadableLogRecord MUST also be able to access Instrumentation Scope and Resource — [L281](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L281)
- [ ] Trace context fields MUST be populated from resolved Context when emitted — [L285](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L285)
- [ ] Counts for attributes due to collection limits MUST be available for exporters — [L289](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L289)

### ReadWriteLogRecord
- [ ] A function receiving ReadWriteLogRecord MUST additionally be able to modify Timestamp, ObservedTimestamp, SeverityText, SeverityNumber, Body, Attributes, TraceId, SpanId, TraceFlags, EventName — [L302](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L302)

### LogRecord Limits
- [ ] LogRecord attributes MUST adhere to common rules of attribute limits — [L323](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L323)
- [ ] If SDK implements attribute limits, it MUST provide a way to change them via LoggerProvider configuration — [L326](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L326)
- [ ] Options SHOULD be called LogRecordLimits — [L331](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L331)
- [ ] There SHOULD be a message in SDK log when attribute is discarded due to limit — [L345](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L345)
- [ ] The message MUST be printed at most once per LogRecord — [L347](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L347)

### LogRecordProcessor
- [ ] SDK MUST allow each pipeline to end with an individual exporter — [L363](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L363)
- [ ] SDK MUST allow users to implement and configure custom processors — [L365](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L365)

### OnEmit
- [ ] OnEmit SHOULD NOT block or throw exceptions — [L397](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L397)
- [ ] For processor registered directly on LoggerProvider, logRecord mutations MUST be visible in next registered processors — [L409](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L409)

### Enabled (Processor)
- [ ] Any modifications to parameters inside Enabled MUST NOT be propagated to the caller — [L439](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L439)

### Processor Shutdown
- [ ] Shutdown SHOULD be called only once for each LogRecordProcessor instance — [L462](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L462)
- [ ] After Shutdown, subsequent calls to OnEmit are not allowed; SDKs SHOULD ignore gracefully — [L463](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L463)
- [ ] Shutdown SHOULD provide a way to let caller know success/failure/timeout — [L466](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L466)
- [ ] Shutdown MUST include the effects of ForceFlush — [L469](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L469)
- [ ] Shutdown SHOULD complete or abort within some timeout — [L471](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L471)

### Processor ForceFlush
- [ ] Tasks associated with LogRecords received prior to ForceFlush SHOULD be completed as soon as possible — [L480](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L480)
- [ ] If processor has associated exporter, it SHOULD try to call Export and then ForceFlush on it — [L484](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L484)
- [ ] Built-in LogRecordProcessors MUST do so — [L486](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L486)
- [ ] If timeout is specified, LogRecordProcessor MUST prioritize honoring the timeout — [L487](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L487)
- [ ] ForceFlush SHOULD provide a way to let caller know success/failure/timeout — [L492](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L492)
- [ ] ForceFlush SHOULD only be called in absolutely necessary cases — [L495](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L495)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L500](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L500)

### Built-in Processors
- [ ] Standard SDK MUST implement both simple and batch processors — [L507](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L507)
- [ ] Other common processing scenarios SHOULD be first considered for out-of-process implementation — [L510](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L510)

### Simple Processor
- [ ] Processor MUST synchronize calls to LogRecordExporter's Export — [L521](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L521)

### Batching Processor
- [ ] Processor MUST synchronize calls to LogRecordExporter's Export — [L534](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L534)

### LogRecordExporter
- [ ] Each implementation MUST document the concurrency characteristics the SDK requires — [L559](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L559)
- [ ] LogRecordExporter MUST support Export, ForceFlush, and Shutdown functions — [L563](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L563)

### Export
- [ ] Export MUST NOT block indefinitely, there MUST be a reasonable upper limit (timeout with Failure) — [L582](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L582)
- [ ] Default SDK's LogRecordProcessors SHOULD NOT implement retry logic — [L586](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L586)

### Exporter ForceFlush
- [ ] ForceFlush SHOULD provide a way to let caller know success/failure/timeout — [L620](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L620)
- [ ] ForceFlush SHOULD only be called in absolutely necessary cases — [L622](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L622)
- [ ] ForceFlush SHOULD complete or abort within some timeout — [L625](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L625)

### Exporter Shutdown
- [ ] Shutdown SHOULD be called only once for each LogRecordExporter instance — [L637](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L637)
- [ ] After Shutdown, subsequent calls to Export are not allowed and SHOULD return Failure — [L638](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L638)
- [ ] Shutdown SHOULD NOT block indefinitely — [L640](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L640)

### Concurrency Requirements (SDK)
- [ ] LoggerProvider: Logger creation, ForceFlush, and Shutdown MUST be safe to be called concurrently — [L654](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L654)
- [ ] Logger: all methods MUST be safe to be called concurrently — [L657](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L657)
- [ ] LogRecordExporter: ForceFlush and Shutdown MUST be safe to be called concurrently — [L659](references/opentelemetry-specification/v1.55.0/logs/sdk.md#L659)

## Logs Exporters

### Console (stdout)

> Ref: [logs/sdk_exporters/stdout.md](references/opentelemetry-specification/v1.55.0/logs/sdk_exporters/stdout.md)

- [ ] Documentation SHOULD warn users that output format is not standardized — [L13](references/opentelemetry-specification/v1.55.0/logs/sdk_exporters/stdout.md#L13)
- [ ] By default stdout exporter SHOULD be paired with a simple processor — [L33](references/opentelemetry-specification/v1.55.0/logs/sdk_exporters/stdout.md#L33)

## OTLP Protocol

> Ref: [specification.md](references/opentelemetry-proto/v1.10.0/docs/specification.md)

### General
- [ ] All server components MUST support no compression (`none`) and gzip compression — [L87](references/opentelemetry-proto/v1.10.0/docs/specification.md#L87)

### OTLP/gRPC Concurrent Requests
- [ ] Implementations needing high throughput SHOULD support concurrent Unary calls — [L129](references/opentelemetry-proto/v1.10.0/docs/specification.md#L129)
- [ ] Client SHOULD send new requests without waiting for earlier responses — [L130](references/opentelemetry-proto/v1.10.0/docs/specification.md#L130)
- [ ] Number of concurrent requests SHOULD be configurable — [L137](references/opentelemetry-proto/v1.10.0/docs/specification.md#L137)
- [ ] Client implementation SHOULD expose option to turn on/off waiting during shutdown — [L151](references/opentelemetry-proto/v1.10.0/docs/specification.md#L151)
- [ ] If client unable to deliver, it SHOULD record that data was not delivered — [L155](references/opentelemetry-proto/v1.10.0/docs/specification.md#L155)

### OTLP/gRPC Response
- [ ] Response MUST be the appropriate message for Full Success, Partial Success, and Failure — [L160](references/opentelemetry-proto/v1.10.0/docs/specification.md#L160)

### Full Success (gRPC)
- [ ] If server receives empty request, it SHOULD respond with success — [L170](references/opentelemetry-proto/v1.10.0/docs/specification.md#L170)
- [ ] On success, server response MUST be Export<signal>ServiceResponse message — [L172](references/opentelemetry-proto/v1.10.0/docs/specification.md#L172)
- [ ] Server MUST leave `partial_success` field unset on successful response — [L178](references/opentelemetry-proto/v1.10.0/docs/specification.md#L178)

### Partial Success (gRPC)
- [ ] Server response MUST be same Export<signal>ServiceResponse message — [L185](references/opentelemetry-proto/v1.10.0/docs/specification.md#L185)
- [ ] Server MUST initialize `partial_success` field and MUST set rejected count — [L189](references/opentelemetry-proto/v1.10.0/docs/specification.md#L189)
- [ ] Server SHOULD populate `error_message` field with human-readable English message — [L197](references/opentelemetry-proto/v1.10.0/docs/specification.md#L197)
- [ ] When server fully accepts but conveys warnings, `rejected_<signal>` MUST be 0 and `error_message` MUST be non-empty — [L205](references/opentelemetry-proto/v1.10.0/docs/specification.md#L205)
- [ ] Client MUST NOT retry when it receives partial success with `partial_success` populated — [L208](references/opentelemetry-proto/v1.10.0/docs/specification.md#L208)

### Failures (gRPC)
- [ ] Client SHOULD record error and may retry on retryable errors — [L217](references/opentelemetry-proto/v1.10.0/docs/specification.md#L217)
- [ ] Client MUST NOT retry on not-retryable errors; MUST drop telemetry data — [L222](references/opentelemetry-proto/v1.10.0/docs/specification.md#L222)
- [ ] Client SHOULD maintain counter of dropped data — [L226](references/opentelemetry-proto/v1.10.0/docs/specification.md#L226)
- [ ] Server SHOULD indicate retryable errors using Unavailable code — [L228](references/opentelemetry-proto/v1.10.0/docs/specification.md#L228)
- [ ] Client SHOULD interpret gRPC status codes as retryable/not-retryable per the table — [L269](references/opentelemetry-proto/v1.10.0/docs/specification.md#L269)
- [ ] When retrying, client SHOULD implement exponential backoff — [L291](references/opentelemetry-proto/v1.10.0/docs/specification.md#L291)
- [ ] Client SHOULD interpret RESOURCE_EXHAUSTED as retryable only if server signals recovery via RetryInfo — [L295](references/opentelemetry-proto/v1.10.0/docs/specification.md#L295)

### OTLP/gRPC Throttling
- [ ] If server unable to keep up, it SHOULD signal to client — [L309](references/opentelemetry-proto/v1.10.0/docs/specification.md#L309)
- [ ] Client MUST throttle itself to avoid overwhelming the server — [L310](references/opentelemetry-proto/v1.10.0/docs/specification.md#L310)
- [ ] Server SHOULD return Unavailable error for backpressure — [L312](references/opentelemetry-proto/v1.10.0/docs/specification.md#L312)
- [ ] Client SHOULD follow RetryInfo recommendations — [L344](references/opentelemetry-proto/v1.10.0/docs/specification.md#L344)
- [ ] Server SHOULD choose retry_delay big enough to recover but not too big — [L365](references/opentelemetry-proto/v1.10.0/docs/specification.md#L365)

### OTLP/gRPC Default Port
- [ ] Default network port for OTLP/gRPC is 4317 — [L381](references/opentelemetry-proto/v1.10.0/docs/specification.md#L381)

### OTLP/HTTP
- [ ] OTLP/HTTP uses HTTP POST requests — [L390](references/opentelemetry-proto/v1.10.0/docs/specification.md#L390)
- [ ] Implementations that use HTTP/2 SHOULD fallback to HTTP/1.1 if HTTP/2 cannot be established — [L392](references/opentelemetry-proto/v1.10.0/docs/specification.md#L392)

### Binary Protobuf Encoding
- [ ] Client and server MUST set "Content-Type: application/x-protobuf" for binary Protobuf payload — [L400](references/opentelemetry-proto/v1.10.0/docs/specification.md#L400)

### JSON Protobuf Encoding
- [ ] traceId and spanId MUST be represented as case-insensitive hex-encoded strings (not base64) — [L409](references/opentelemetry-proto/v1.10.0/docs/specification.md#L409)
- [ ] Values of enum fields MUST be encoded as integer values; enum name strings MUST NOT be used — [L418](references/opentelemetry-proto/v1.10.0/docs/specification.md#L418)
- [ ] OTLP/JSON receivers MUST ignore message fields with unknown names and MUST unmarshal as if unknown field was not present — [L426](references/opentelemetry-proto/v1.10.0/docs/specification.md#L426)
- [ ] Client and server MUST set "Content-Type: application/json" for JSON Protobuf payload — [L443](references/opentelemetry-proto/v1.10.0/docs/specification.md#L443)

### OTLP/HTTP Request
- [ ] Default URL path for traces is `/v1/traces` — [L454](references/opentelemetry-proto/v1.10.0/docs/specification.md#L454)
- [ ] Default URL path for metrics is `/v1/metrics` — [L459](references/opentelemetry-proto/v1.10.0/docs/specification.md#L459)
- [ ] Default URL path for logs is `/v1/logs` — [L462](references/opentelemetry-proto/v1.10.0/docs/specification.md#L462)
- [ ] Client MAY gzip content and in that case MUST include "Content-Encoding: gzip" header — [L469](references/opentelemetry-proto/v1.10.0/docs/specification.md#L469)

### OTLP/HTTP Response
- [ ] Response body MUST be the appropriate serialized Protobuf message — [L478](references/opentelemetry-proto/v1.10.0/docs/specification.md#L478)
- [ ] Server MUST set "Content-Type: application/x-protobuf" for binary response — [L482](references/opentelemetry-proto/v1.10.0/docs/specification.md#L482)
- [ ] Server MUST set "Content-Type: application/json" for JSON response — [L484](references/opentelemetry-proto/v1.10.0/docs/specification.md#L484)
- [ ] Server MUST use same Content-Type in response as received in request — [L485](references/opentelemetry-proto/v1.10.0/docs/specification.md#L485)

### Full Success (HTTP)
- [ ] If server receives empty request, it SHOULD respond with success — [L498](references/opentelemetry-proto/v1.10.0/docs/specification.md#L498)
- [ ] On success, server MUST respond with HTTP 200 OK — [L500](references/opentelemetry-proto/v1.10.0/docs/specification.md#L500)
- [ ] Server MUST leave `partial_success` field unset on successful response — [L507](references/opentelemetry-proto/v1.10.0/docs/specification.md#L507)

### Partial Success (HTTP)
- [ ] Server MUST respond with HTTP 200 OK — [L513](references/opentelemetry-proto/v1.10.0/docs/specification.md#L513)
- [ ] Server MUST initialize `partial_success` field and MUST set rejected count — [L518](references/opentelemetry-proto/v1.10.0/docs/specification.md#L518)
- [ ] Server SHOULD populate `error_message` with human-readable English message — [L525](references/opentelemetry-proto/v1.10.0/docs/specification.md#L525)
- [ ] When server fully accepts but conveys warnings, `rejected_<signal>` MUST be 0 and `error_message` MUST be non-empty — [L533](references/opentelemetry-proto/v1.10.0/docs/specification.md#L533)
- [ ] Client MUST NOT retry when it receives partial success — [L536](references/opentelemetry-proto/v1.10.0/docs/specification.md#L536)

### Failures (HTTP)
- [ ] If processing fails, server MUST respond with appropriate HTTP 4xx or 5xx status code — [L541](references/opentelemetry-proto/v1.10.0/docs/specification.md#L541)
- [ ] Response body for all 4xx and 5xx MUST be Protobuf-encoded Status message — [L545](references/opentelemetry-specification/v1.55.0/../opentelemetry-proto/v1.10.0/docs/specification.md#L545)
- [ ] Status.message SHOULD contain developer-facing error message — [L554](references/opentelemetry-proto/v1.10.0/docs/specification.md#L554)
- [ ] Server SHOULD use HTTP response status codes to indicate retryable/not-retryable — [L560](references/opentelemetry-proto/v1.10.0/docs/specification.md#L560)
- [ ] Client SHOULD honour HTTP response status codes as retryable/not-retryable — [L562](references/opentelemetry-proto/v1.10.0/docs/specification.md#L562)
- [ ] Requests with retryable response codes (429, 502, 503, 504) SHOULD be retried — [L566](references/opentelemetry-proto/v1.10.0/docs/specification.md#L566)
- [ ] All other 4xx or 5xx response status codes MUST NOT be retried — [L568](references/opentelemetry-proto/v1.10.0/docs/specification.md#L568)

### Bad Data (HTTP)
- [ ] If data cannot be decoded or is permanently invalid, server MUST respond with HTTP 400 Bad Request — [L580](references/opentelemetry-proto/v1.10.0/docs/specification.md#L580)
- [ ] Status.details SHOULD contain BadRequest describing the bad data — [L581](references/opentelemetry-proto/v1.10.0/docs/specification.md#L581)
- [ ] Client MUST NOT retry when receiving HTTP 400 — [L586](references/opentelemetry-proto/v1.10.0/docs/specification.md#L586)

### OTLP/HTTP Throttling
- [ ] If server receives more requests than allowed, it SHOULD respond with 429 or 503 — [L592](references/opentelemetry-proto/v1.10.0/docs/specification.md#L592)
- [ ] Client SHOULD honour Retry-After header if present — [L597](references/opentelemetry-proto/v1.10.0/docs/specification.md#L597)
- [ ] If retryable error and no Retry-After, client SHOULD implement exponential backoff — [L600](references/opentelemetry-proto/v1.10.0/docs/specification.md#L600)

### All Other Responses
- [ ] If server disconnects without response, client SHOULD retry with exponential backoff — [L608](references/opentelemetry-proto/v1.10.0/docs/specification.md#L608)

### OTLP/HTTP Connection
- [ ] If client cannot connect, it SHOULD retry with exponential backoff with random jitter — [L614](references/opentelemetry-proto/v1.10.0/docs/specification.md#L614)
- [ ] Client SHOULD keep connection alive between requests — [L618](references/opentelemetry-proto/v1.10.0/docs/specification.md#L618)
- [ ] Server SHOULD accept binary Protobuf and JSON Protobuf on same port — [L620](references/opentelemetry-proto/v1.10.0/docs/specification.md#L620)

### OTLP/HTTP Concurrent Requests
- [ ] Maximum number of parallel connections SHOULD be configurable — [L632](references/opentelemetry-proto/v1.10.0/docs/specification.md#L632)

### OTLP/HTTP Default Port
- [ ] Default network port for OTLP/HTTP is 4318 — [L636](references/opentelemetry-proto/v1.10.0/docs/specification.md#L636)

### Implementation Recommendations
- [ ] Client SHOULD implement queuing, acknowledgment handling, and retry logic per destination — [L648](references/opentelemetry-proto/v1.10.0/docs/specification.md#L648)
- [ ] Queues SHOULD reference shared, immutable data to minimize memory overhead — [L649](references/opentelemetry-proto/v1.10.0/docs/specification.md#L649)
- [ ] Senders SHOULD NOT create empty envelopes (zero spans/metrics/logs) — [L669](references/opentelemetry-proto/v1.10.0/docs/specification.md#L669)

### Future Versions and Interoperability
- [ ] Interoperability MUST be ensured between all non-obsolete OTLP versions — [L695](references/opentelemetry-proto/v1.10.0/docs/specification.md#L695)
- [ ] Implementation supporting new optional capability MUST adjust behavior to match peer that does not support it — [L723](references/opentelemetry-proto/v1.10.0/docs/specification.md#L723)

## OTLP Exporter Configuration

> Ref: [protocol/exporter.md](references/opentelemetry-specification/v1.55.0/protocol/exporter.md)

### Configuration Options
- [ ] All configuration options MUST be available to configure OTLP exporter — [L13](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L13)
- [ ] Each configuration option MUST be overridable by a signal specific option — [L14](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L14)
- [ ] OTLP/HTTP endpoint implementation MUST honor scheme, host, port, path URL components — [L17](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L17)
- [ ] When using OTEL_EXPORTER_OTLP_ENDPOINT, exporters MUST construct per-signal URLs — [L26](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L26)
- [ ] Protocol options MUST be one of: `grpc`, `http/protobuf`, `http/json` — [L71](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L71)
- [ ] SDKs SHOULD default endpoint to `http` scheme — [L77](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L77)
- [ ] Obsolete env vars SHOULD continue to be supported if already implemented — [L83](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L83)

### Endpoint URLs for OTLP/HTTP
- [ ] For per-signal vars, URL MUST be used as-is; if no path, root `/` MUST be used — [L101](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L101)
- [ ] If no per-signal config, OTEL_EXPORTER_OTLP_ENDPOINT is base URL; signals sent to relative paths (v1/traces, v1/metrics, v1/logs) — [L105](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L105)
- [ ] SDK MUST NOT modify URL in ways other than specified — [L115](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L115)

### Specify Protocol
- [ ] SDKs SHOULD support both `grpc` and `http/protobuf` and MUST support at least one — [L169](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L169)
- [ ] If only one supported, it SHOULD be `http/protobuf` — [L170](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L170)
- [ ] Default transport SHOULD be `http/protobuf` — [L173](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L173)

### Retry
- [ ] Transient errors MUST be handled with a retry strategy — [L184](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L184)
- [ ] Retry strategy MUST implement exponential back-off with jitter — [L184](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L184)

### User Agent
- [ ] OTLP exporters SHOULD emit a User-Agent header identifying exporter, language, and version — [L205](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L205)
- [ ] User-Agent format SHOULD follow RFC 7231 — [L211](references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L211)

## Environment Variables

> Ref: [configuration/sdk-environment-variables.md](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md)

### Implementation Guidelines
- [ ] If env vars are implemented, they SHOULD use the names and parsing behavior specified — [L49](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L49)
- [ ] They SHOULD also follow common configuration specification — [L50](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L50)
- [ ] Environment-based configuration MUST have a direct code configuration equivalent — [L56](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L56)

### Parsing Empty Value
- [ ] SDK MUST interpret empty value of env var same as when variable is unset — [L60](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L60)

### Boolean
- [ ] Boolean MUST be set to true only by case-insensitive `"true"` — [L67](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L67)
- [ ] Implementation MUST NOT extend this definition with additional true values — [L68](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L68)
- [ ] Any value not explicitly defined as true MUST be interpreted as false — [L70](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L70)
- [ ] If value other than true/false/empty/unset used, warning SHOULD be logged — [L72](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L72)
- [ ] All Boolean env vars SHOULD be named such that false is the expected safe default — [L73](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L73)
- [ ] Renaming or changing default MUST NOT happen without major version upgrade — [L75](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L75)

### Numeric
- [ ] If user provides unparseable numeric value, implementation SHOULD warn and treat as not set — [L89](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L89)

### Enum
- [ ] Enum values SHOULD be interpreted in a case-insensitive manner — [L103](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L103)
- [ ] If unrecognized enum value, implementation MUST generate warning and gracefully ignore — [L106](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L106)

### General SDK Configuration
- [ ] OTEL_PROPAGATORS values MUST be deduplicated — [L118](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L118)
- [ ] Invalid or unrecognized OTEL_TRACES_SAMPLER_ARG MUST be logged and MUST be otherwise ignored — [L120](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L120)

### Batch LogRecord Processor
- [ ] OTEL_BLRP_SCHEDULE_DELAY default 1000 — [L167](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L167)
- [ ] OTEL_BLRP_EXPORT_TIMEOUT default 30000 — [L168](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L168)
- [ ] OTEL_BLRP_MAX_QUEUE_SIZE default 2048 — [L169](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L169)
- [ ] OTEL_BLRP_MAX_EXPORT_BATCH_SIZE default 512, must be <= MAX_QUEUE_SIZE — [L170](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L170)

### Attribute Limits
- [ ] Implementations SHOULD only offer env vars for attribute types where SDK implements truncation — [L174](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L174)
- [ ] OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT default no limit — [L181](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L181)
- [ ] OTEL_ATTRIBUTE_COUNT_LIMIT default 128 — [L182](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L182)

### LogRecord Limits
- [ ] OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT default no limit — [L203](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L203)
- [ ] OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT default 128 — [L204](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L204)

### Exporter Selection
- [ ] OTEL_TRACES_EXPORTER default `otlp` — [L243](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L243)
- [ ] OTEL_METRICS_EXPORTER default `otlp` — [L244](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L244)
- [ ] OTEL_LOGS_EXPORTER default `otlp` — [L245](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L245)
- [ ] `logging` exporter value SHOULD NOT be supported by new implementations — [L254](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L254)

### Language Specific
- [ ] Language specific env vars SHOULD follow `OTEL_{LANGUAGE}_{FEATURE}` convention — [L359](references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L359)