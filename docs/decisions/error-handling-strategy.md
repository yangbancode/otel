# Error Handling Strategy

## Question

How does the SDK handle errors without crashing instrumented applications? What patterns ensure the OTel mandate of "never crash the host"?

## Decision

TBD

## Compliance

- [API Propagators](../compliance/api-propagators.md)
  * Operations — [L83](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L83)
  * Operations — [L84](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L84)
  * Operations — [L93](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L93)
  * Operations — [L102](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L102)
  * Operations — [L102](../references/opentelemetry-specification/v1.55.0/context/api-propagators.md#L102)
- [Trace API](../compliance/trace-api.md)
  * TraceState — [L284](../references/opentelemetry-specification/v1.55.0/trace/api.md#L284)
  * TraceState — [L291](../references/opentelemetry-specification/v1.55.0/trace/api.md#L291)
  * TraceState — [L292](../references/opentelemetry-specification/v1.55.0/trace/api.md#L292)
  * TraceState — [L293](../references/opentelemetry-specification/v1.55.0/trace/api.md#L293)
  * TraceState — [L294](../references/opentelemetry-specification/v1.55.0/trace/api.md#L294)
  * TraceState — [L295](../references/opentelemetry-specification/v1.55.0/trace/api.md#L295)
- [Logs SDK](../compliance/logs-sdk.md)
  * OnEmit — [L397](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L397)
  * OnEmit — [L409](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L409)
