# SDK Internal Logging Strategy

## Question

How does the SDK emit its own diagnostic messages (invalid name warnings, attribute truncation, duplicate instruments)? How to leverage Erlang's `:logger` for OTel-internal logging?

## Decision

TBD

## Compliance

- [Trace SDK](../compliance/trace-sdk.md)
  * Span Limits — L836, L841, L845, L846, L873, L875
- [Metrics SDK](../compliance/metrics-sdk.md)
  * Meter Creation — L121, L124, L126, L131, L132, L133
  * Duplicate Instrument Registration — L912, L919, L919, L923, L926, L928, L942
  * Name Conflict — L950
- [Logs SDK](../compliance/logs-sdk.md)
  * Logger Creation — L69, L72, L74, L79, L80, L81
