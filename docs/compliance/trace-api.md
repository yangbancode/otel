# Trace API

> Ref: [trace/api.md](../references/opentelemetry-specification/v1.55.0/trace/api.md)

### TracerProvider

- [x] API SHOULD provide a way to set/register and access a global default TracerProvider — [L96](../references/opentelemetry-specification/v1.55.0/trace/api.md#L96)
- [x] Implementations of TracerProvider SHOULD allow creating an arbitrary number of TracerProvider instances — [L104](../references/opentelemetry-specification/v1.55.0/trace/api.md#L104)
- [x] TracerProvider MUST provide the function: Get a Tracer — [L109](../references/opentelemetry-specification/v1.55.0/trace/api.md#L109)

### Get a Tracer

- [x] Get a Tracer API MUST accept `name` parameter — [L115](../references/opentelemetry-specification/v1.55.0/trace/api.md#L115)
- [x] `name` SHOULD uniquely identify the instrumentation scope — [L117](../references/opentelemetry-specification/v1.55.0/trace/api.md#L117)
- [x] If invalid name (null or empty string), a working Tracer MUST be returned as fallback rather than returning null or throwing an exception — [L126](../references/opentelemetry-specification/v1.55.0/trace/api.md#L126)
- [x] If invalid name, Tracer's `name` property SHOULD be set to an empty string — [L128](../references/opentelemetry-specification/v1.55.0/trace/api.md#L128)
- [x] If invalid name, a message reporting that the specified value is invalid SHOULD be logged — [L129](../references/opentelemetry-specification/v1.55.0/trace/api.md#L129)
- [x] Get a Tracer API SHOULD accept `attributes` parameter (since 1.13.0) — [L139](../references/opentelemetry-specification/v1.55.0/trace/api.md#L139)
- [x] Implementations MUST NOT require users to repeatedly obtain a Tracer with the same identity to pick up configuration changes — [L146](../references/opentelemetry-specification/v1.55.0/trace/api.md#L146)

### Context Interaction

- [x] API MUST provide functionality to extract the Span from a Context instance — [L164](../references/opentelemetry-specification/v1.55.0/trace/api.md#L164)
- [x] API MUST provide functionality to combine the Span with a Context instance, creating a new Context instance — [L164](../references/opentelemetry-specification/v1.55.0/trace/api.md#L164)
- [x] API users SHOULD NOT have access to the Context Key used by the Tracing API implementation — [L170](../references/opentelemetry-specification/v1.55.0/trace/api.md#L170)
- [x] If language has implicit Context propagation, API SHOULD provide get currently active span from implicit context — [L174](../references/opentelemetry-specification/v1.55.0/trace/api.md#L174)
- [x] If language has implicit Context propagation, API SHOULD provide set currently active span into implicit context — [L174](../references/opentelemetry-specification/v1.55.0/trace/api.md#L174)
- [x] Context interaction functionality SHOULD be fully implemented in the API when possible — [L182](../references/opentelemetry-specification/v1.55.0/trace/api.md#L182)

### Tracer

- [x] Tracer MUST provide function to create a new Span — [L193](../references/opentelemetry-specification/v1.55.0/trace/api.md#L193)
- [x] Tracer SHOULD provide function to report if Tracer is Enabled — [L197](../references/opentelemetry-specification/v1.55.0/trace/api.md#L197)
- [x] Enabled API MUST be structured in a way for parameters to be added — [L209](../references/opentelemetry-specification/v1.55.0/trace/api.md#L209)
- [x] Enabled API MUST return a language idiomatic boolean type — [L212](../references/opentelemetry-specification/v1.55.0/trace/api.md#L212)

### SpanContext

- [x] API MUST implement methods to create a SpanContext — [L252](../references/opentelemetry-specification/v1.55.0/trace/api.md#L252)
- [x] SpanContext creation functionality MUST be fully implemented in the API — [L253](../references/opentelemetry-specification/v1.55.0/trace/api.md#L253)
- [x] SpanContext creation SHOULD NOT be overridable — [L253](../references/opentelemetry-specification/v1.55.0/trace/api.md#L253)

### Retrieving the TraceId and SpanId

- [x] API MUST allow retrieving the TraceId and SpanId in Hex and Binary forms — [L258](../references/opentelemetry-specification/v1.55.0/trace/api.md#L258)
- [x] Hex TraceId MUST be a 32-hex-character lowercase string — [L261](../references/opentelemetry-specification/v1.55.0/trace/api.md#L261)
- [x] Hex SpanId MUST be a 16-hex-character lowercase string — [L262](../references/opentelemetry-specification/v1.55.0/trace/api.md#L262)
- [x] Binary TraceId MUST be a 16-byte array — [L263](../references/opentelemetry-specification/v1.55.0/trace/api.md#L263)
- [x] Binary SpanId MUST be an 8-byte array — [L264](../references/opentelemetry-specification/v1.55.0/trace/api.md#L264)
- [x] API SHOULD NOT expose details about how TraceId/SpanId are internally stored — [L266](../references/opentelemetry-specification/v1.55.0/trace/api.md#L266)

### IsValid

- [x] An API called IsValid MUST be provided that returns true if SpanContext has a non-zero TraceID and non-zero SpanID — [L270](../references/opentelemetry-specification/v1.55.0/trace/api.md#L270)

### IsRemote

- [x] An API called IsRemote MUST be provided that returns true if SpanContext was propagated from a remote parent — [L275](../references/opentelemetry-specification/v1.55.0/trace/api.md#L275)
- [ ] When extracting SpanContext through Propagators API, IsRemote MUST return true — [L278](../references/opentelemetry-specification/v1.55.0/trace/api.md#L278)
- [x] For SpanContext of any child spans, IsRemote MUST return false — [L278](../references/opentelemetry-specification/v1.55.0/trace/api.md#L278)

### TraceState

- [x] Tracing API MUST provide at least: get value for a given key, add a new key/value pair, update an existing value for a given key, delete a key/value pair — [L284](../references/opentelemetry-specification/v1.55.0/trace/api.md#L284)
- [x] TraceState operations MUST follow the rules described in the W3C Trace Context specification — [L291](../references/opentelemetry-specification/v1.55.0/trace/api.md#L291)
- [x] All mutating operations MUST return a new TraceState with the modifications applied — [L292](../references/opentelemetry-specification/v1.55.0/trace/api.md#L292)
- [x] TraceState MUST at all times be valid according to W3C Trace Context specification — [L293](../references/opentelemetry-specification/v1.55.0/trace/api.md#L293)
- [x] Every mutating operation MUST validate input parameters — [L294](../references/opentelemetry-specification/v1.55.0/trace/api.md#L294)
- [x] If invalid value is passed the operation MUST NOT return TraceState containing invalid data and MUST follow general error handling guidelines — [L295](../references/opentelemetry-specification/v1.55.0/trace/api.md#L295)

### Span

- [ ] Span name SHOULD be the most general string that identifies a (statistically) interesting class of Spans — [L329](../references/opentelemetry-specification/v1.55.0/trace/api.md#L329)
- [ ] Generality SHOULD be prioritized over human-readability — [L333](../references/opentelemetry-specification/v1.55.0/trace/api.md#L333)
- [ ] Span's start time SHOULD be set to current time on span creation — [L365](../references/opentelemetry-specification/v1.55.0/trace/api.md#L365)
- [x] After Span is created, it SHOULD be possible to change its name, set Attributes, add Events, and set Status — [L366](../references/opentelemetry-specification/v1.55.0/trace/api.md#L366)
- [x] Name, Attributes, Events, Status MUST NOT be changed after the Span's end time has been set — [L368](../references/opentelemetry-specification/v1.55.0/trace/api.md#L368)
- [x] Implementations SHOULD NOT provide access to a Span's attributes besides its SpanContext — [L371](../references/opentelemetry-specification/v1.55.0/trace/api.md#L371)
- [x] Alternative implementations MUST NOT allow callers to create Spans directly; all Spans MUST be created via a Tracer — [L375](../references/opentelemetry-specification/v1.55.0/trace/api.md#L375)

### Span Creation

- [ ] There MUST NOT be any API for creating a Span other than with a Tracer — [L380](../references/opentelemetry-specification/v1.55.0/trace/api.md#L380)
- [ ] Span creation MUST NOT set the newly created Span as active Span in current Context by default (for languages with implicit Context propagation) — [L382](../references/opentelemetry-specification/v1.55.0/trace/api.md#L382)
- [ ] API MUST accept: span name (required) — [L387](../references/opentelemetry-specification/v1.55.0/trace/api.md#L387)
- [ ] API MUST accept: parent Context or indication of root Span — [L390](../references/opentelemetry-specification/v1.55.0/trace/api.md#L390)
- [ ] API MUST NOT accept a Span or SpanContext as parent, only a full Context — [L393](../references/opentelemetry-specification/v1.55.0/trace/api.md#L393)
- [ ] The semantic parent of the Span MUST be determined according to the rules in Determining the Parent Span from a Context — [L395](../references/opentelemetry-specification/v1.55.0/trace/api.md#L395)
- [ ] API documentation MUST state that adding attributes at span creation is preferred to calling SetAttribute later — [L403](../references/opentelemetry-specification/v1.55.0/trace/api.md#L403)
- [ ] Start timestamp SHOULD only be set when span creation time has already passed — [L408](../references/opentelemetry-specification/v1.55.0/trace/api.md#L408)
- [ ] If API is called at moment of Span logical start, user MUST NOT explicitly set start timestamp — [L410](../references/opentelemetry-specification/v1.55.0/trace/api.md#L410)
- [ ] Implementations MUST provide an option to create a Span as a root span — [L416](../references/opentelemetry-specification/v1.55.0/trace/api.md#L416)
- [ ] Implementations MUST generate a new TraceId for each root span created — [L417](../references/opentelemetry-specification/v1.55.0/trace/api.md#L417)
- [ ] For a Span with a parent, TraceId MUST be the same as the parent — [L418](../references/opentelemetry-specification/v1.55.0/trace/api.md#L418)
- [ ] Child span MUST inherit all TraceState values of its parent by default — [L419](../references/opentelemetry-specification/v1.55.0/trace/api.md#L419)
- [ ] Any span that is created MUST also be ended — [L426](../references/opentelemetry-specification/v1.55.0/trace/api.md#L426)

### Specifying Links

- [ ] During Span creation, a user MUST have the ability to record links to other Spans — [L444](../references/opentelemetry-specification/v1.55.0/trace/api.md#L444)

### Span Operations — Get Context

- [x] Span interface MUST provide an API that returns the SpanContext for the given Span — [L457](../references/opentelemetry-specification/v1.55.0/trace/api.md#L457)
- [x] Returned SpanContext value MUST be the same for the entire Span lifetime — [L460](../references/opentelemetry-specification/v1.55.0/trace/api.md#L460)

### Span Operations — IsRecording

- [x] After a Span is ended, IsRecording SHOULD return false — [L478](../references/opentelemetry-specification/v1.55.0/trace/api.md#L478)
- [x] IsRecording SHOULD NOT take any parameters — [L483](../references/opentelemetry-specification/v1.55.0/trace/api.md#L483)
- [x] IsRecording SHOULD be used to avoid expensive computations of Span attributes or events when Span is not recorded — [L485](../references/opentelemetry-specification/v1.55.0/trace/api.md#L485)

### Span Operations — Set Attributes

- [x] Span MUST have the ability to set Attributes — [L497](../references/opentelemetry-specification/v1.55.0/trace/api.md#L497)
- [x] Span interface MUST provide an API to set a single Attribute — [L499](../references/opentelemetry-specification/v1.55.0/trace/api.md#L499)
- [ ] Setting an attribute with the same key as an existing attribute SHOULD overwrite the existing attribute's value — [L510](../references/opentelemetry-specification/v1.55.0/trace/api.md#L510)

### Span Operations — Add Events

- [x] Span MUST have the ability to add events — [L522](../references/opentelemetry-specification/v1.55.0/trace/api.md#L522)
- [x] Span interface MUST provide an API to record a single Event — [L533](../references/opentelemetry-specification/v1.55.0/trace/api.md#L533)
- [ ] Events SHOULD preserve the order in which they are recorded — [L544](../references/opentelemetry-specification/v1.55.0/trace/api.md#L544)

### Span Operations — Add Link

- [x] Span MUST have the ability to add Links after its creation — [L562](../references/opentelemetry-specification/v1.55.0/trace/api.md#L562)

### Span Operations — Set Status

- [ ] Description MUST only be used with the Error StatusCode value — [L574](../references/opentelemetry-specification/v1.55.0/trace/api.md#L574)
- [x] Span interface MUST provide an API to set the Status — [L594](../references/opentelemetry-specification/v1.55.0/trace/api.md#L594)
- [ ] Description MUST be IGNORED for StatusCode Ok & Unset values — [L599](../references/opentelemetry-specification/v1.55.0/trace/api.md#L599)
- [ ] Status code SHOULD remain unset except in specific circumstances — [L602](../references/opentelemetry-specification/v1.55.0/trace/api.md#L602)
- [ ] Attempt to set value Unset SHOULD be ignored — [L603](../references/opentelemetry-specification/v1.55.0/trace/api.md#L603)
- [ ] When status is set to Error by instrumentation libraries, the Description SHOULD be documented and predictable — [L606](../references/opentelemetry-specification/v1.55.0/trace/api.md#L606)
- [ ] Instrumentation Libraries SHOULD publish their own conventions for status descriptions not covered by semantic conventions — [L609](../references/opentelemetry-specification/v1.55.0/trace/api.md#L609)
- [ ] Instrumentation Libraries SHOULD NOT set status code to Ok unless explicitly configured to do so — [L613](../references/opentelemetry-specification/v1.55.0/trace/api.md#L613)
- [ ] Instrumentation Libraries SHOULD leave status code as Unset unless there is an error — [L614](../references/opentelemetry-specification/v1.55.0/trace/api.md#L614)
- [ ] When span status is set to Ok it SHOULD be considered final and any further attempts to change it SHOULD be ignored — [L619](../references/opentelemetry-specification/v1.55.0/trace/api.md#L619)
- [ ] Analysis tools SHOULD respond to an Ok status by suppressing any errors they would otherwise generate — [L622](../references/opentelemetry-specification/v1.55.0/trace/api.md#L622)

### Span Operations — End

- [x] Implementations SHOULD ignore all subsequent calls to End and any other Span methods after Span is finished — [L652](../references/opentelemetry-specification/v1.55.0/trace/api.md#L652)
- [ ] All API implementations of language-specific end methods MUST internally call the End method — [L659](../references/opentelemetry-specification/v1.55.0/trace/api.md#L659)
- [ ] End MUST NOT have any effects on child spans — [L662](../references/opentelemetry-specification/v1.55.0/trace/api.md#L662)
- [ ] End MUST NOT inactivate the Span in any Context it is active in — [L665](../references/opentelemetry-specification/v1.55.0/trace/api.md#L665)
- [ ] It MUST still be possible to use an ended span as parent via a Context it is contained in — [L666](../references/opentelemetry-specification/v1.55.0/trace/api.md#L666)
- [ ] If end timestamp is omitted, this MUST be treated equivalent to passing the current time — [L673](../references/opentelemetry-specification/v1.55.0/trace/api.md#L673)
- [x] End operation itself MUST NOT perform blocking I/O on the calling thread — [L677](../references/opentelemetry-specification/v1.55.0/trace/api.md#L677)
- [ ] Any locking used SHOULD be minimized and SHOULD be removed entirely if possible — [L678](../references/opentelemetry-specification/v1.55.0/trace/api.md#L678)

### Span Operations — Record Exception

- [x] Languages SHOULD provide a RecordException method if the language uses exceptions — [L686](../references/opentelemetry-specification/v1.55.0/trace/api.md#L686)
- [x] RecordException MUST record an exception as an Event with the conventions outlined in the exceptions document — [L693](../references/opentelemetry-specification/v1.55.0/trace/api.md#L693)
- [x] The minimum required argument SHOULD be no more than only an exception object — [L695](../references/opentelemetry-specification/v1.55.0/trace/api.md#L695)
- [x] If RecordException is provided, the method MUST accept an optional parameter to provide additional event attributes — [L697](../references/opentelemetry-specification/v1.55.0/trace/api.md#L697)
- [ ] Additional event attributes SHOULD be done in the same way as for the AddEvent method — [L699](../references/opentelemetry-specification/v1.55.0/trace/api.md#L699)

### Span Lifetime

- [ ] Start and end time as well as Event's timestamps MUST be recorded at a time of calling of corresponding API — [L715](../references/opentelemetry-specification/v1.55.0/trace/api.md#L715)

### Wrapping a SpanContext in a Span

- [ ] API MUST provide an operation for wrapping a SpanContext with an object implementing the Span interface — [L720](../references/opentelemetry-specification/v1.55.0/trace/api.md#L720)
- [ ] If a new type is required, it SHOULD NOT be exposed publicly if possible — [L724](../references/opentelemetry-specification/v1.55.0/trace/api.md#L724)
- [ ] If a new type must be publicly exposed, it SHOULD be named NonRecordingSpan — [L727](../references/opentelemetry-specification/v1.55.0/trace/api.md#L727)
- [ ] GetContext MUST return the wrapped SpanContext — [L731](../references/opentelemetry-specification/v1.55.0/trace/api.md#L731)
- [ ] IsRecording MUST return false — [L732](../references/opentelemetry-specification/v1.55.0/trace/api.md#L732)
- [ ] The remaining functionality of Span MUST be defined as no-op operations — [L735](../references/opentelemetry-specification/v1.55.0/trace/api.md#L735)
- [ ] Wrapping functionality MUST be fully implemented in the API — [L739](../references/opentelemetry-specification/v1.55.0/trace/api.md#L739)
- [ ] Wrapping functionality SHOULD NOT be overridable — [L739](../references/opentelemetry-specification/v1.55.0/trace/api.md#L739)

### Link

- [ ] A user MUST have the ability to record links to other SpanContexts — [L805](../references/opentelemetry-specification/v1.55.0/trace/api.md#L805)
- [ ] API MUST provide an API to record a single Link — [L815](../references/opentelemetry-specification/v1.55.0/trace/api.md#L815)
- [ ] Implementations SHOULD record links containing SpanContext with empty TraceId or SpanId as long as either attribute set or TraceState is non-empty — [L821](../references/opentelemetry-specification/v1.55.0/trace/api.md#L821)
- [ ] Span SHOULD preserve the order in which Links are set — [L830](../references/opentelemetry-specification/v1.55.0/trace/api.md#L830)
- [ ] API documentation MUST state that adding links at span creation is preferred to calling AddLink later — [L832](../references/opentelemetry-specification/v1.55.0/trace/api.md#L832)

### Concurrency Requirements

- [ ] TracerProvider — all methods MUST be safe for concurrent use — [L842](../references/opentelemetry-specification/v1.55.0/trace/api.md#L842)
- [ ] Tracer — all methods MUST be safe for concurrent use — [L845](../references/opentelemetry-specification/v1.55.0/trace/api.md#L845)
- [ ] Span — all methods MUST be safe for concurrent use — [L848](../references/opentelemetry-specification/v1.55.0/trace/api.md#L848)
- [ ] Event — Events are immutable and MUST be safe for concurrent use — [L851](../references/opentelemetry-specification/v1.55.0/trace/api.md#L851)
- [ ] Link — Links are immutable and SHOULD be safe for concurrent use — [L853](../references/opentelemetry-specification/v1.55.0/trace/api.md#L853)

### Behavior of the API in the absence of an installed SDK

- [ ] API MUST return a non-recording Span with the SpanContext in the parent Context — [L865](../references/opentelemetry-specification/v1.55.0/trace/api.md#L865)
- [ ] If the Span in the parent Context is already non-recording, it SHOULD be returned directly without instantiating a new Span — [L867](../references/opentelemetry-specification/v1.55.0/trace/api.md#L867)
- [ ] If parent Context contains no Span, an empty non-recording Span MUST be returned (all-zero Span and Trace IDs, empty Tracestate, unsampled TraceFlags) — [L869](../references/opentelemetry-specification/v1.55.0/trace/api.md#L869)
