# Common

> Ref: [common/README.md](../references/opentelemetry-specification/v1.55.0/common/README.md)

### AnyValue
- [ ] Homogeneous array MUST NOT contain values of different types — [L45](../references/opentelemetry-specification/v1.55.0/common/README.md#L45)
- [ ] APIs SHOULD be documented that using array and map values may carry higher performance overhead — [L56](../references/opentelemetry-specification/v1.55.0/common/README.md#L56)
- [ ] Empty value, zero, empty string, or empty array are meaningful and MUST be stored and passed on to processors/exporters — [L60](../references/opentelemetry-specification/v1.55.0/common/README.md#L60)
- [ ] `null` values within arrays SHOULD generally be avoided unless language constraints make this impossible — [L64](../references/opentelemetry-specification/v1.55.0/common/README.md#L64)
- [ ] If impossible to prevent null in arrays, null values MUST be preserved as-is — [L67](../references/opentelemetry-specification/v1.55.0/common/README.md#L67)

### map<string, AnyValue>
- [ ] Case sensitivity of keys MUST be preserved — [L80](../references/opentelemetry-specification/v1.55.0/common/README.md#L80)
- [ ] Implementation MUST by default enforce that exported maps contain only unique keys — [L85](../references/opentelemetry-specification/v1.55.0/common/README.md#L85)
- [ ] If option to allow duplicate keys is provided, it MUST be documented that handling is unpredictable — [L93](../references/opentelemetry-specification/v1.55.0/common/README.md#L93)

### AnyValue Representation for Non-OTLP Protocols
- [ ] Values SHOULD be represented as strings following the encoding rules — [L103](../references/opentelemetry-specification/v1.55.0/common/README.md#L103)
- [ ] Strings SHOULD be represented as-is without additional encoding — [L113](../references/opentelemetry-specification/v1.55.0/common/README.md#L113)
- [ ] Strings SHOULD NOT be encoded as JSON strings (with surrounding quotes) — [L114](../references/opentelemetry-specification/v1.55.0/common/README.md#L114)
- [ ] Booleans SHOULD be represented as JSON booleans — [L120](../references/opentelemetry-specification/v1.55.0/common/README.md#L120)
- [ ] Integers SHOULD be represented as JSON numbers — [L127](../references/opentelemetry-specification/v1.55.0/common/README.md#L127)
- [ ] Floating point numbers SHOULD be represented as JSON numbers — [L134](../references/opentelemetry-specification/v1.55.0/common/README.md#L134)
- [ ] NaN and Infinity SHOULD be represented as `NaN`, `Infinity`, `-Infinity` — [L137](../references/opentelemetry-specification/v1.55.0/common/README.md#L137)
- [ ] NaN/Infinity SHOULD NOT be encoded as JSON strings — [L139](../references/opentelemetry-specification/v1.55.0/common/README.md#L139)
- [ ] Byte arrays SHOULD be Base64-encoded — [L145](../references/opentelemetry-specification/v1.55.0/common/README.md#L145)
- [ ] Byte arrays SHOULD NOT be encoded as JSON strings — [L146](../references/opentelemetry-specification/v1.55.0/common/README.md#L146)
- [ ] Empty values SHOULD be represented as the empty string — [L152](../references/opentelemetry-specification/v1.55.0/common/README.md#L152)
- [ ] Empty values SHOULD NOT be encoded as JSON string — [L153](../references/opentelemetry-specification/v1.55.0/common/README.md#L153)
- [ ] Arrays SHOULD be represented as JSON arrays — [L157](../references/opentelemetry-specification/v1.55.0/common/README.md#L157)
- [ ] Nested byte arrays SHOULD be represented as Base64-encoded JSON strings — [L159](../references/opentelemetry-specification/v1.55.0/common/README.md#L159)
- [ ] Nested empty values SHOULD be represented as JSON null — [L161](../references/opentelemetry-specification/v1.55.0/common/README.md#L161)
- [ ] Nested NaN/Infinity in arrays SHOULD be represented as JSON strings — [L162](../references/opentelemetry-specification/v1.55.0/common/README.md#L162)
- [ ] Maps SHOULD be represented as JSON objects — [L169](../references/opentelemetry-specification/v1.55.0/common/README.md#L169)
- [ ] Nested byte arrays in maps SHOULD be Base64-encoded JSON strings — [L171](../references/opentelemetry-specification/v1.55.0/common/README.md#L171)
- [ ] Nested empty values in maps SHOULD be JSON null — [L173](../references/opentelemetry-specification/v1.55.0/common/README.md#L173)
- [ ] Nested NaN/Infinity in maps SHOULD be JSON strings — [L174](../references/opentelemetry-specification/v1.55.0/common/README.md#L174)

### Attribute
- [ ] Attribute MUST have key-value pair properties — [L183](../references/opentelemetry-specification/v1.55.0/common/README.md#L183)
- [ ] Attribute key MUST be a non-null and non-empty string — [L185](../references/opentelemetry-specification/v1.55.0/common/README.md#L185)
- [ ] Attribute value MUST be one of types defined in AnyValue — [L187](../references/opentelemetry-specification/v1.55.0/common/README.md#L187)

### Attribute Collections
- [ ] Implementation MUST by default enforce that exported attribute collections contain only unique keys — [L215](../references/opentelemetry-specification/v1.55.0/common/README.md#L215)
- [ ] Setting attribute with same key SHOULD overwrite existing value — [L223](../references/opentelemetry-specification/v1.55.0/common/README.md#L223)
- [ ] If option to allow duplicate keys is provided, it MUST be documented that handling is unpredictable — [L241](../references/opentelemetry-specification/v1.55.0/common/README.md#L241)

### Attribute Limits
- [ ] SDK SHOULD apply truncation as per configurable parameters by default — [L255](../references/opentelemetry-specification/v1.55.0/common/README.md#L255)
- [ ] If string value exceeds length limit, SDKs MUST truncate to at most the limit — [L263](../references/opentelemetry-specification/v1.55.0/common/README.md#L263)
- [ ] If byte array exceeds length limit, SDKs MUST truncate to at most the limit — [L267](../references/opentelemetry-specification/v1.55.0/common/README.md#L267)
- [ ] A value that is not a string or byte array MUST NOT be truncated — [L274](../references/opentelemetry-specification/v1.55.0/common/README.md#L274)
- [ ] If adding attribute exceeds count limit, SDK MUST discard that attribute — [L278](../references/opentelemetry-specification/v1.55.0/common/README.md#L278)
- [ ] If attribute is not over count limit, it MUST NOT be discarded — [L282](../references/opentelemetry-specification/v1.55.0/common/README.md#L282)
- [ ] Log about truncation/discard MUST NOT be emitted more than once per record — [L285](../references/opentelemetry-specification/v1.55.0/common/README.md#L285)
- [ ] If SDK implements limits, it MUST provide a way to change them programmatically — [L288](../references/opentelemetry-specification/v1.55.0/common/README.md#L288)
- [ ] Configuration option names SHOULD be the same as listed — [L289](../references/opentelemetry-specification/v1.55.0/common/README.md#L289)
- [ ] If both general and model-specific limit exist, SDK MUST first attempt model-specific, then general — [L294](../references/opentelemetry-specification/v1.55.0/common/README.md#L294)
- [ ] If neither are defined, SDK MUST try model-specific default, then global default — [L296](../references/opentelemetry-specification/v1.55.0/common/README.md#L296)
- [ ] `AttributeCountLimit` default=128, `AttributeValueLengthLimit` default=Infinity — [L305](../references/opentelemetry-specification/v1.55.0/common/README.md#L305)
- [ ] Resource attributes SHOULD be exempt from attribute limits — [L310](../references/opentelemetry-specification/v1.55.0/common/README.md#L310)
