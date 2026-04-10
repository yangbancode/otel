# Context

> Ref: [context/README.md](../references/opentelemetry-specification/v1.55.0/context/README.md)

### Overview
- [x] Context MUST be immutable, write operations MUST result in new Context — [L37](../references/opentelemetry-specification/v1.55.0/context/README.md#L37)

### Create a Key
- [x] API MUST accept the key name parameter — [L65](../references/opentelemetry-specification/v1.55.0/context/README.md#L65)
- [x] Multiple calls to CreateKey with same name SHOULD NOT return same value — [L65](../references/opentelemetry-specification/v1.55.0/context/README.md#L65)
- [x] API MUST return an opaque object representing the newly created key — [L67](../references/opentelemetry-specification/v1.55.0/context/README.md#L67)

### Get Value
- [x] API MUST accept the Context and the key parameters — [L74](../references/opentelemetry-specification/v1.55.0/context/README.md#L74)
- [x] API MUST return the value in the Context for the specified key — [L79](../references/opentelemetry-specification/v1.55.0/context/README.md#L79)

### Set Value
- [x] API MUST accept the Context, key, and value parameters — [L86](../references/opentelemetry-specification/v1.55.0/context/README.md#L86)
- [x] API MUST return a new Context containing the new value — [L92](../references/opentelemetry-specification/v1.55.0/context/README.md#L92)

### Optional Global Operations
- [x] These operations SHOULD only be used to implement automatic scope switching by SDK components — [L98](../references/opentelemetry-specification/v1.55.0/context/README.md#L98)
- [x] Get current Context: API MUST return the Context associated with caller's current execution unit — [L103](../references/opentelemetry-specification/v1.55.0/context/README.md#L103)
- [x] Attach Context: API MUST accept the Context parameter — [L109](../references/opentelemetry-specification/v1.55.0/context/README.md#L109)
- [x] Attach Context: API MUST return a value that can be used as Token — [L113](../references/opentelemetry-specification/v1.55.0/context/README.md#L113)
- [x] Detach Context: API MUST accept a Token parameter — [L133](../references/opentelemetry-specification/v1.55.0/context/README.md#L133)
