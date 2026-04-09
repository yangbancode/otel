# Logs API

> Ref: [logs/api.md](../references/opentelemetry-specification/v1.55.0/logs/api.md)

### LoggerProvider
- [ ] API SHOULD provide a way to set/register and access a global default LoggerProvider — [L59](../references/opentelemetry-specification/v1.55.0/logs/api.md#L59)
- [ ] LoggerProvider MUST provide Get a Logger function — [L64](../references/opentelemetry-specification/v1.55.0/logs/api.md#L64)

### Get a Logger
- [ ] API MUST accept `name` parameter (instrumentation scope) — [L70](../references/opentelemetry-specification/v1.55.0/logs/api.md#L70)
- [ ] API MUST accept optional `version` parameter — [L85](../references/opentelemetry-specification/v1.55.0/logs/api.md#L85)
- [ ] API MUST accept optional `schema_url` parameter — [L88](../references/opentelemetry-specification/v1.55.0/logs/api.md#L88)
- [ ] API MUST accept optional `attributes` parameter, structured for variable number including none — [L92](../references/opentelemetry-specification/v1.55.0/logs/api.md#L92)

### Logger
- [ ] Logger MUST provide function to Emit a LogRecord — [L103](../references/opentelemetry-specification/v1.55.0/logs/api.md#L103)
- [ ] Logger SHOULD provide function to report if Enabled — [L107](../references/opentelemetry-specification/v1.55.0/logs/api.md#L107)

### Emit a LogRecord
- [ ] API MUST accept Timestamp (optional) — [L117](../references/opentelemetry-specification/v1.55.0/logs/api.md#L117)
- [ ] API MUST accept Observed Timestamp (optional) — [L118](../references/opentelemetry-specification/v1.55.0/logs/api.md#L118)
- [ ] API MUST accept Context; if implicit supported SHOULD be optional, MUST use current if unspecified — [L119](../references/opentelemetry-specification/v1.55.0/logs/api.md#L119)
- [ ] When only explicit Context supported, parameter SHOULD be required — [L122](../references/opentelemetry-specification/v1.55.0/logs/api.md#L122)
- [ ] API MUST accept Severity Number (optional) — [L123](../references/opentelemetry-specification/v1.55.0/logs/api.md#L123)
- [ ] API MUST accept Severity Text (optional) — [L124](../references/opentelemetry-specification/v1.55.0/logs/api.md#L124)
- [ ] API MUST accept Body (optional) — [L125](../references/opentelemetry-specification/v1.55.0/logs/api.md#L125)
- [ ] API MUST accept Attributes (optional) — [L126](../references/opentelemetry-specification/v1.55.0/logs/api.md#L126)
- [ ] API MUST accept Event Name (optional) — [L127](../references/opentelemetry-specification/v1.55.0/logs/api.md#L127)

### Enabled
- [ ] Logger SHOULD provide Enabled API — [L135](../references/opentelemetry-specification/v1.55.0/logs/api.md#L135)
- [ ] Enabled API SHOULD accept Context parameter (optional if implicit supported, MUST use current if unspecified) — [L140](../references/opentelemetry-specification/v1.55.0/logs/api.md#L140)
- [ ] When only explicit Context, accepting Context parameter is REQUIRED — [L143](../references/opentelemetry-specification/v1.55.0/logs/api.md#L143)
- [ ] Enabled API SHOULD accept Severity Number (optional) — [L144](../references/opentelemetry-specification/v1.55.0/logs/api.md#
Now I have all 11 files read. Let me compile the complete compliance checklist.
