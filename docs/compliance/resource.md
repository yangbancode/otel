# Resource

> Ref: [resource/sdk.md](../references/opentelemetry-specification/v1.55.0/resource/sdk.md)

### Resource SDK
- [ ] SDK MUST allow for creation of Resources and associating them with telemetry — [L22](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L22)
- [ ] All Spans produced by any Tracer from provider MUST be associated with Resource — [L29](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L29)

### SDK-provided Resource Attributes
- [ ] SDK MUST provide access to Resource with at least SDK-provided default value attributes — [L39](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L39)
- [ ] This resource MUST be associated with TracerProvider/MeterProvider if no other resource specified — [L41](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L41)

### Create
- [ ] Interface MUST provide way to create new resource from Attributes — [L58](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L58)

### Merge
- [ ] Interface MUST provide way to merge old and updating resource into new resource — [L71](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L71)
- [ ] Resulting resource MUST have all attributes from both input resources — [L78](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L78)
- [ ] If key exists on both, value of updating resource MUST be picked — [L79](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L79)

### Detecting Resource Information
- [ ] Custom resource detectors for generic platforms MUST be implemented as separate packages — [L107](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L107)
- [ ] Resource detector packages MUST provide method that returns a resource — [L110](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L110)
- [ ] Failure to detect resource info MUST NOT be considered an error — [L122](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L122)
- [ ] Error during detection attempt SHOULD be considered an error — [L123](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L123)
- [ ] Detectors populating semconv attributes MUST ensure Schema URL matches — [L127](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L127)
- [ ] Empty Schema URL SHOULD be used if detector doesn't populate known semconv attributes — [L128](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L128)
- [ ] Multiple detectors with different non-empty Schema URLs MUST be an error — [L133](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L133)

### Environment Variable Resource
- [ ] SDK MUST extract info from OTEL_RESOURCE_ATTRIBUTES and merge as secondary resource — [L179](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L179)
- [ ] All attribute values MUST be considered strings — [L186](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L186)
- [ ] The `,` and `=` characters in keys and values MUST be percent encoded — [L187](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L187)
- [ ] On decoding error, entire value SHOULD be discarded and error SHOULD be reported — [L192](../references/opentelemetry-specification/v1.55.0/resource/sdk.md#L192)
