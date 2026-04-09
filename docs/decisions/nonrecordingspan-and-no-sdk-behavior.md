# NonRecordingSpan & No-SDK Behavior

## Question

How to implement NonRecordingSpan and API-only behavior when no SDK is installed?

## Decision

TBD

## Compliance

- [Trace API](../compliance/trace-api.md)
  * SpanContext — L252, L253, L253
  * Span — L329, L333, L365, L366, L368, L371, L375
  * Wrapping a SpanContext in a Span — L720, L724, L727, L731, L732, L735, L739, L739
  * Behavior of the API in the absence of an installed SDK — L865, L867, L869
