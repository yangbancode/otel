# Environment Variables

> Ref: [configuration/sdk-environment-variables.md](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md)

### Implementation Guidelines
- [ ] If env vars are implemented, they SHOULD use the names and parsing behavior specified — [L49](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L49)
- [ ] They SHOULD also follow common configuration specification — [L50](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L50)
- [ ] Environment-based configuration MUST have a direct code configuration equivalent — [L56](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L56)

### Parsing Empty Value
- [ ] SDK MUST interpret empty value of env var same as when variable is unset — [L60](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L60)

### Boolean
- [ ] Boolean MUST be set to true only by case-insensitive `"true"` — [L67](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L67)
- [ ] Implementation MUST NOT extend this definition with additional true values — [L68](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L68)
- [ ] Any value not explicitly defined as true MUST be interpreted as false — [L70](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L70)
- [ ] If value other than true/false/empty/unset used, warning SHOULD be logged — [L72](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L72)
- [ ] All Boolean env vars SHOULD be named such that false is the expected safe default — [L73](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L73)
- [ ] Renaming or changing default MUST NOT happen without major version upgrade — [L75](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L75)

### Numeric
- [ ] If user provides unparseable numeric value, implementation SHOULD warn and treat as not set — [L89](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L89)

### Enum
- [ ] Enum values SHOULD be interpreted in a case-insensitive manner — [L103](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L103)
- [ ] If unrecognized enum value, implementation MUST generate warning and gracefully ignore — [L106](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L106)

### General SDK Configuration
- [ ] OTEL_PROPAGATORS values MUST be deduplicated — [L118](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L118)
- [ ] Invalid or unrecognized OTEL_TRACES_SAMPLER_ARG MUST be logged and MUST be otherwise ignored — [L120](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L120)

### Batch LogRecord Processor
- [ ] OTEL_BLRP_SCHEDULE_DELAY default 1000 — [L167](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L167)
- [ ] OTEL_BLRP_EXPORT_TIMEOUT default 30000 — [L168](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L168)
- [ ] OTEL_BLRP_MAX_QUEUE_SIZE default 2048 — [L169](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L169)
- [ ] OTEL_BLRP_MAX_EXPORT_BATCH_SIZE default 512, must be <= MAX_QUEUE_SIZE — [L170](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L170)

### Attribute Limits
- [ ] Implementations SHOULD only offer env vars for attribute types where SDK implements truncation — [L174](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L174)
- [ ] OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT default no limit — [L181](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L181)
- [ ] OTEL_ATTRIBUTE_COUNT_LIMIT default 128 — [L182](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L182)

### LogRecord Limits
- [ ] OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT default no limit — [L203](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L203)
- [ ] OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT default 128 — [L204](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L204)

### Exporter Selection
- [ ] OTEL_TRACES_EXPORTER default `otlp` — [L243](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L243)
- [ ] OTEL_METRICS_EXPORTER default `otlp` — [L244](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L244)
- [ ] OTEL_LOGS_EXPORTER default `otlp` — [L245](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L245)
- [ ] `logging` exporter value SHOULD NOT be supported by new implementations — [L254](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L254)

### Language Specific
- [ ] Language specific env vars SHOULD follow `OTEL_{LANGUAGE}_{FEATURE}` convention — [L359](../references/opentelemetry-specification/v1.55.0/configuration/sdk-environment-variables.md#L359)
