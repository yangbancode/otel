# Context

> Ref: [context/README.md](../references/opentelemetry-specification/v1.55.0/context/README.md)

### Overview
- [ ] Context MUST be immutable, write operations MUST result in new Context — [L37](../references/opentelemetry-specification/v1.55.0/context/README.md#L37)

### Create a Key
- [ ] API MUST accept the key name parameter — [L65](../references/opentelemetry-specification/v1.55.0/context/README.md#L65)
- [ ] Multiple calls to CreateKey with same name SHOULD NOT return same value — [L65](../references/opentelemetry-specification/v1.55.0/context/README.md#L65)
- [ ] API MUST return an opaque object representing the newly created key — [L67](../references/opentelemetry-specification/v1.55.0/context/README.md#L67)

### Get Value
- [ ] API MUST accept the Context and the key parameters — [L74](../references/opentelemetry-specification/v1.55.0/context/README.md#L74)
- [ ] API MUST return the value in the Context for the specified key — [L79](../references/opentelemetry-specification/v1.55.0/context/README.md#L79)

### Set Value
- [ ] API MUST accept the Context, key, and value parameters — [L86](../references/opentelemetry-specification/v1.55.0/context/README.md#L86)
- [ ] API MUST return a new Context containing the new value — [L92](../references/opentelemetry-specification/v1.55.0/context/README.md#L92)

### Optional Global Operations
- [ ] These operations SHOULD only be used to implement automatic scope switching by SDK components — [L98](../references/opentelemetry-specification/v1.55.0/context/README.md#L98)
- [ ] Get current Context: API MUST return the Context associated with caller's current execution unit — [L103](../references/opentelemetry-specification/v1.55.0/context/README.md#L103)
- [ ] Attach Context: API MUST accept the Context parameter — [L109](../references/opentelemetry-specification/v1.55.0/context/README.md#L109)
- [ ] Attach Context: API MUST return a value that can be used as Token — [L113](../references/opentelemetry-specification/v1.55.0/context/README.md#L113)
- [ ] Detach Context: API MUST accept a Token parameter — [L133](../references/opentelemetry-specification/v1.55.0/context/README.md#L133)
