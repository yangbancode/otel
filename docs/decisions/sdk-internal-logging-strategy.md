# SDK Internal Logging Strategy

## Question

How does the SDK emit its own diagnostic messages (invalid name warnings, attribute truncation, duplicate instruments)? How to leverage Erlang's `:logger` for OTel-internal logging?

## Decision

TBD

## Compliance

- [Trace SDK](../compliance/trace-sdk.md)
  * Span Limits — [L836](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L836)
  * Span Limits — [L841](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L841)
  * Span Limits — [L845](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L845)
  * Span Limits — [L846](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L846)
  * Span Limits — [L873](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L873)
  * Span Limits — [L875](../references/opentelemetry-specification/v1.55.0/trace/sdk.md#L875)
- [Metrics SDK](../compliance/metrics-sdk.md)
  * Meter Creation — [L121](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L121)
  * Meter Creation — [L124](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L124)
  * Meter Creation — [L126](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L126)
  * Meter Creation — [L131](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L131)
  * Meter Creation — [L132](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L132)
  * Meter Creation — [L133](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L133)
  * Duplicate Instrument Registration — [L912](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L912)
  * Duplicate Instrument Registration — [L919](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L919)
  * Duplicate Instrument Registration — [L919](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L919)
  * Duplicate Instrument Registration — [L923](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L923)
  * Duplicate Instrument Registration — [L926](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L926)
  * Duplicate Instrument Registration — [L928](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L928)
  * Duplicate Instrument Registration — [L942](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L942)
  * Name Conflict — [L950](../references/opentelemetry-specification/v1.55.0/metrics/sdk.md#L950)
- [Logs SDK](../compliance/logs-sdk.md)
  * Logger Creation — [L69](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L69)
  * Logger Creation — [L72](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L72)
  * Logger Creation — [L74](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L74)
  * Logger Creation — [L79](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L79)
  * Logger Creation — [L80](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L80)
  * Logger Creation — [L81](../references/opentelemetry-specification/v1.55.0/logs/sdk.md#L81)
