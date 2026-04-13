# Resource Detection & Environment Variables

## Question

How to implement resource detectors and OTEL_RESOURCE_ATTRIBUTES parsing on BEAM?

## Decision

### Environment Variable Resource

`Otel.SDK.Resource.from_env/0` parses:
- `OTEL_RESOURCE_ATTRIBUTES` — comma-separated `key=value` pairs, percent-encoded
- `OTEL_SERVICE_NAME` — overrides `service.name` if set

### Resource Detection

Custom resource detectors (Docker, Kubernetes, etc.) are not implemented.
These would be separate packages per spec (L107). The SDK provides:
- SDK default attributes (`telemetry.sdk.*`, `service.name`)
- Environment variable resource

### Merge Order

```
SDK defaults → env var resource (from_env) → user-provided resource
```

Env var resource overrides SDK defaults. User-provided resource (via Application config) overrides both.

## Compliance

- [Compliance](../compliance.md)
  * Detecting Resource Information — L107, L110, L122, L123, L127, L128, L133
  * Environment Variable Resource — L179, L186, L187, L192
