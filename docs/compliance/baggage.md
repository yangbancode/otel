# Baggage

> Ref: [baggage/api.md](../references/opentelemetry-specification/v1.55.0/baggage/api.md)

### Overview
- [ ] Each name MUST be associated with exactly one value — [L38](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L38)
- [ ] Baggage names: Language API SHOULD NOT restrict which strings are used — [L43](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L43)
- [ ] Baggage values: Language API MUST accept any valid UTF-8 string and return same from Get — [L53](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L53)
- [ ] Language API MUST treat both names and values as case sensitive — [L57](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L57)
- [ ] Baggage API MUST be fully functional without installed SDK — [L79](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L79)
- [ ] Baggage container MUST be immutable — [L84](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L84)

### Operations
- [ ] Get Value: MUST provide function that takes name and returns value or null — [L92](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L92)
- [ ] Get All Values: order MUST NOT be significant — [L102](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L102)
- [ ] Set Value: MUST provide function taking name and value, returns new Baggage — [L108](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L108)
- [ ] Remove Value: MUST provide function taking name, returns new Baggage — [L128](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L128)

### Context Interaction
- [ ] If not operating directly on Context, MUST provide extract/insert Baggage from/to Context — [L144](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L144)
- [ ] Users SHOULD NOT have access to Context Key used by Baggage API — [L149](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L149)
- [ ] If implicit Context supported, API SHOULD provide get/set currently active Baggage — [L154](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L154)
- [ ] This functionality SHOULD be fully implemented in the API when possible — [L166](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L166)

### Clear Baggage
- [ ] MUST provide a way to remove all baggage entries from a context — [L172](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L172)

### Propagation
- [ ] API layer or extension MUST include a TextMapPropagator implementing W3C Baggage — [L184](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L184)

### Conflict Resolution
- [ ] If new name/value pair has same name as existing, new pair MUST take precedence — [L207](../references/opentelemetry-specification/v1.55.0/baggage/api.md#L207)
