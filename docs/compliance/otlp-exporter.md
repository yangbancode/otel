# OTLP Exporter Configuration

> Ref: [protocol/exporter.md](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md)

### Configuration Options
- [ ] All configuration options MUST be available to configure OTLP exporter — [L13](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L13)
- [ ] Each configuration option MUST be overridable by a signal specific option — [L14](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L14)
- [ ] OTLP/HTTP endpoint implementation MUST honor scheme, host, port, path URL components — [L17](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L17)
- [ ] When using OTEL_EXPORTER_OTLP_ENDPOINT, exporters MUST construct per-signal URLs — [L26](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L26)
- [ ] Protocol options MUST be one of: `grpc`, `http/protobuf`, `http/json` — [L71](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L71)
- [ ] SDKs SHOULD default endpoint to `http` scheme — [L77](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L77)
- [ ] Obsolete env vars SHOULD continue to be supported if already implemented — [L83](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L83)

### Endpoint URLs for OTLP/HTTP
- [ ] For per-signal vars, URL MUST be used as-is; if no path, root `/` MUST be used — [L101](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L101)
- [ ] If no per-signal config, OTEL_EXPORTER_OTLP_ENDPOINT is base URL; signals sent to relative paths (v1/traces, v1/metrics, v1/logs) — [L105](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L105)
- [ ] SDK MUST NOT modify URL in ways other than specified — [L115](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L115)

### Specify Protocol
- [ ] SDKs SHOULD support both `grpc` and `http/protobuf` and MUST support at least one — [L169](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L169)
- [ ] If only one supported, it SHOULD be `http/protobuf` — [L170](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L170)
- [ ] Default transport SHOULD be `http/protobuf` — [L173](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L173)

### Retry
- [ ] Transient errors MUST be handled with a retry strategy — [L184](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L184)
- [ ] Retry strategy MUST implement exponential back-off with jitter — [L184](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L184)

### User Agent
- [ ] OTLP exporters SHOULD emit a User-Agent header identifying exporter, language, and version — [L205](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L205)
- [ ] User-Agent format SHOULD follow RFC 7231 — [L211](../references/opentelemetry-specification/v1.55.0/protocol/exporter.md#L211)
