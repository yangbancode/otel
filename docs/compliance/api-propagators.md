# API Propagators

> Ref: [context/api-propagators.md](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md)

### Operations
- [x] Propagators MUST define Inject and Extract operations — [L83](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L83)
- [x] Each Propagator type MUST define the specific carrier type — [L84](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L84)
- [x] Inject: Propagator MUST retrieve appropriate value from Context first — [L93](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L93)
- [x] Extract: implementation MUST NOT throw an exception on parse failure — [L102](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L102)
- [x] Extract: MUST NOT store a new value in Context on parse failure — [L102](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L102)

### TextMap Propagator
- [x] Key/value pairs MUST only consist of US-ASCII characters valid for HTTP header fields (RFC 9110) — [L122](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L122)
- [x] Getter and Setter MUST be stateless and allowed to be saved as constants — [L130](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L130)
- [x] Setter Set: implementation SHOULD preserve casing if protocol is case insensitive, otherwise MUST preserve casing — [L183](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L183)
- [x] Getter Keys: MUST return list of all keys in carrier — [L209](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L209)
- [x] Getter Get: MUST return first value of given key or null — [L223](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L223)
- [x] Getter Get: MUST be case insensitive for HTTP requests — [L230](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L230)
- [ ] GetAll (if implemented): MUST return all values of given propagation key — [L240](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L240)
- [ ] GetAll: SHOULD return values in same order as carrier — [L241](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L241)
- [ ] GetAll: SHOULD return empty collection if key doesn't exist — [L242](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L242)
- [ ] GetAll: MUST be case insensitive for HTTP requests — [L249](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L249)

### Composite Propagator
- [x] Implementations MUST offer facility to group multiple Propagators as single entity — [L261](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L261)
- [x] There MUST be functions for: create, extract, inject on composite propagator — [L272](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L272)

### Global Propagators
- [x] API MUST provide a way to obtain a propagator for each supported type — [L310](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L310)
- [x] Instrumentation libraries SHOULD call propagators to extract/inject context on all remote calls — [L311](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L311)
- [x] API MUST use no-op propagators unless explicitly configured otherwise — [L322](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L322)
- [ ] Pre-configured Propagators SHOULD default to composite with W3C Trace Context + Baggage — [L329](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L329)
- [ ] Platforms with pre-configured propagators MUST allow them to be disabled or overridden — [L332](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L332)
- [x] Get Global Propagator: method MUST exist for each supported type — [L336](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L336)
- [x] Set Global Propagator: method MUST exist for each supported type — [L342](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L342)

### Propagators Distribution
- [ ] W3C TraceContext and W3C Baggage MUST be maintained and distributed — [L352](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L352)

### W3C Trace Context Requirements
- [x] MUST parse and validate `traceparent` and `tracestate` per W3C Trace Context Level 2 — [L383](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L383)
- [x] MUST propagate valid `traceparent` using same header — [L383](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L383)
- [x] MUST propagate valid `tracestate` unless empty — [L383](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L383)
