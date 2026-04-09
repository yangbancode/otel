# OTLP Protocol

> Ref: [specification.md](../references/opentelemetry-proto/v1.10.0/docs/specification.md)

### General
- [ ] All server components MUST support no compression (`none`) and gzip compression — [L87](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L87)

### OTLP/gRPC Concurrent Requests
- [ ] Implementations needing high throughput SHOULD support concurrent Unary calls — [L129](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L129)
- [ ] Client SHOULD send new requests without waiting for earlier responses — [L130](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L130)
- [ ] Number of concurrent requests SHOULD be configurable — [L137](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L137)
- [ ] Client implementation SHOULD expose option to turn on/off waiting during shutdown — [L151](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L151)
- [ ] If client unable to deliver, it SHOULD record that data was not delivered — [L155](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L155)

### OTLP/gRPC Response
- [ ] Response MUST be the appropriate message for Full Success, Partial Success, and Failure — [L160](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L160)

### Full Success (gRPC)
- [ ] If server receives empty request, it SHOULD respond with success — [L170](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L170)
- [ ] On success, server response MUST be Export<signal>ServiceResponse message — [L172](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L172)
- [ ] Server MUST leave `partial_success` field unset on successful response — [L178](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L178)

### Partial Success (gRPC)
- [ ] Server response MUST be same Export<signal>ServiceResponse message — [L185](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L185)
- [ ] Server MUST initialize `partial_success` field and MUST set rejected count — [L189](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L189)
- [ ] Server SHOULD populate `error_message` field with human-readable English message — [L197](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L197)
- [ ] When server fully accepts but conveys warnings, `rejected_<signal>` MUST be 0 and `error_message` MUST be non-empty — [L205](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L205)
- [ ] Client MUST NOT retry when it receives partial success with `partial_success` populated — [L208](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L208)

### Failures (gRPC)
- [ ] Client SHOULD record error and may retry on retryable errors — [L217](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L217)
- [ ] Client MUST NOT retry on not-retryable errors; MUST drop telemetry data — [L222](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L222)
- [ ] Client SHOULD maintain counter of dropped data — [L226](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L226)
- [ ] Server SHOULD indicate retryable errors using Unavailable code — [L228](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L228)
- [ ] Client SHOULD interpret gRPC status codes as retryable/not-retryable per the table — [L269](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L269)
- [ ] When retrying, client SHOULD implement exponential backoff — [L291](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L291)
- [ ] Client SHOULD interpret RESOURCE_EXHAUSTED as retryable only if server signals recovery via RetryInfo — [L295](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L295)

### OTLP/gRPC Throttling
- [ ] If server unable to keep up, it SHOULD signal to client — [L309](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L309)
- [ ] Client MUST throttle itself to avoid overwhelming the server — [L310](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L310)
- [ ] Server SHOULD return Unavailable error for backpressure — [L312](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L312)
- [ ] Client SHOULD follow RetryInfo recommendations — [L344](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L344)
- [ ] Server SHOULD choose retry_delay big enough to recover but not too big — [L365](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L365)

### OTLP/gRPC Default Port
- [ ] Default network port for OTLP/gRPC is 4317 — [L381](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L381)

### OTLP/HTTP
- [ ] OTLP/HTTP uses HTTP POST requests — [L390](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L390)
- [ ] Implementations that use HTTP/2 SHOULD fallback to HTTP/1.1 if HTTP/2 cannot be established — [L392](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L392)

### Binary Protobuf Encoding
- [ ] Client and server MUST set "Content-Type: application/x-protobuf" for binary Protobuf payload — [L400](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L400)

### JSON Protobuf Encoding
- [ ] traceId and spanId MUST be represented as case-insensitive hex-encoded strings (not base64) — [L409](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L409)
- [ ] Values of enum fields MUST be encoded as integer values; enum name strings MUST NOT be used — [L418](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L418)
- [ ] OTLP/JSON receivers MUST ignore message fields with unknown names and MUST unmarshal as if unknown field was not present — [L426](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L426)
- [ ] Client and server MUST set "Content-Type: application/json" for JSON Protobuf payload — [L443](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L443)

### OTLP/HTTP Request
- [ ] Default URL path for traces is `/v1/traces` — [L454](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L454)
- [ ] Default URL path for metrics is `/v1/metrics` — [L459](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L459)
- [ ] Default URL path for logs is `/v1/logs` — [L462](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L462)
- [ ] Client MAY gzip content and in that case MUST include "Content-Encoding: gzip" header — [L469](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L469)

### OTLP/HTTP Response
- [ ] Response body MUST be the appropriate serialized Protobuf message — [L478](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L478)
- [ ] Server MUST set "Content-Type: application/x-protobuf" for binary response — [L482](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L482)
- [ ] Server MUST set "Content-Type: application/json" for JSON response — [L484](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L484)
- [ ] Server MUST use same Content-Type in response as received in request — [L485](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L485)

### Full Success (HTTP)
- [ ] If server receives empty request, it SHOULD respond with success — [L498](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L498)
- [ ] On success, server MUST respond with HTTP 200 OK — [L500](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L500)
- [ ] Server MUST leave `partial_success` field unset on successful response — [L507](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L507)

### Partial Success (HTTP)
- [ ] Server MUST respond with HTTP 200 OK — [L513](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L513)
- [ ] Server MUST initialize `partial_success` field and MUST set rejected count — [L518](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L518)
- [ ] Server SHOULD populate `error_message` with human-readable English message — [L525](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L525)
- [ ] When server fully accepts but conveys warnings, `rejected_<signal>` MUST be 0 and `error_message` MUST be non-empty — [L533](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L533)
- [ ] Client MUST NOT retry when it receives partial success — [L536](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L536)

### Failures (HTTP)
- [ ] If processing fails, server MUST respond with appropriate HTTP 4xx or 5xx status code — [L541](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L541)
- [ ] Response body for all 4xx and 5xx MUST be Protobuf-encoded Status message — [L545](../references/opentelemetry-specification/v1.55.0/../opentelemetry-proto/v1.10.0/docs/specification.md#L545)
- [ ] Status.message SHOULD contain developer-facing error message — [L554](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L554)
- [ ] Server SHOULD use HTTP response status codes to indicate retryable/not-retryable — [L560](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L560)
- [ ] Client SHOULD honour HTTP response status codes as retryable/not-retryable — [L562](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L562)
- [ ] Requests with retryable response codes (429, 502, 503, 504) SHOULD be retried — [L566](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L566)
- [ ] All other 4xx or 5xx response status codes MUST NOT be retried — [L568](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L568)

### Bad Data (HTTP)
- [ ] If data cannot be decoded or is permanently invalid, server MUST respond with HTTP 400 Bad Request — [L580](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L580)
- [ ] Status.details SHOULD contain BadRequest describing the bad data — [L581](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L581)
- [ ] Client MUST NOT retry when receiving HTTP 400 — [L586](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L586)

### OTLP/HTTP Throttling
- [ ] If server receives more requests than allowed, it SHOULD respond with 429 or 503 — [L592](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L592)
- [ ] Client SHOULD honour Retry-After header if present — [L597](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L597)
- [ ] If retryable error and no Retry-After, client SHOULD implement exponential backoff — [L600](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L600)

### All Other Responses
- [ ] If server disconnects without response, client SHOULD retry with exponential backoff — [L608](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L608)

### OTLP/HTTP Connection
- [ ] If client cannot connect, it SHOULD retry with exponential backoff with random jitter — [L614](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L614)
- [ ] Client SHOULD keep connection alive between requests — [L618](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L618)
- [ ] Server SHOULD accept binary Protobuf and JSON Protobuf on same port — [L620](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L620)

### OTLP/HTTP Concurrent Requests
- [ ] Maximum number of parallel connections SHOULD be configurable — [L632](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L632)

### OTLP/HTTP Default Port
- [ ] Default network port for OTLP/HTTP is 4318 — [L636](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L636)

### Implementation Recommendations
- [ ] Client SHOULD implement queuing, acknowledgment handling, and retry logic per destination — [L648](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L648)
- [ ] Queues SHOULD reference shared, immutable data to minimize memory overhead — [L649](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L649)
- [ ] Senders SHOULD NOT create empty envelopes (zero spans/metrics/logs) — [L669](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L669)

### Future Versions and Interoperability
- [ ] Interoperability MUST be ensured between all non-obsolete OTLP versions — [L695](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L695)
- [ ] Implementation supporting new optional capability MUST adjust behavior to match peer that does not support it — [L723](../references/opentelemetry-proto/v1.10.0/docs/specification.md#L723)
