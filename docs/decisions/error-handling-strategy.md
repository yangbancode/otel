# Error Handling Strategy

## Question

How does the SDK handle errors without crashing instrumented applications? What patterns ensure the OTel mandate of "never crash the host"?

## Decision

TBD

## Compliance

- [API Propagators](../compliance/api-propagators.md)
  * Operations — L83, L84, L93, L102, L102
- [Trace API](../compliance/trace-api.md)
  * TraceState — L284, L291, L292, L293, L294, L295
- [Logs SDK](../compliance/logs-sdk.md)
  * OnEmit — L397, L409
