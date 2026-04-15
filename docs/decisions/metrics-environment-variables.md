# Metrics Environment Variables

## Question

How to parse and apply OTEL_* environment variables for Metrics configuration (OTEL_METRICS_EXPORTER, OTEL_EXPORTER_OTLP_METRICS_ENDPOINT, etc.)?

## Decision

### Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `OTEL_METRICS_EXPORTER` | enum | `otlp` | Metrics exporter (`otlp`, `console`, `none`) |
| `OTEL_METRICS_EXEMPLAR_FILTER` | enum | `trace_based` | Exemplar filter (`always_on`, `always_off`, `trace_based`) |
| `OTEL_METRIC_EXPORT_INTERVAL` | int | `60000` | Export interval in ms |
| `OTEL_METRIC_EXPORT_TIMEOUT` | int | `30000` | Export timeout in ms |

### Implementation

Same pattern as Trace environment variables. Added
`maybe_put_metrics_env/1` to `Otel.SDK.Configuration.read_env_vars/0`.

Parsing rules follow existing conventions:
- Empty/nil values treated as unset
- Values are lowercased and trimmed
- Unknown enum values fall back to defaults
- Integer values parsed via `Integer.parse`, unparseable defaults to 0

Metrics env vars are stored under the `:metrics` key in the merged
config map. When no metrics env vars are set, the key is absent.

### Modules

| Module | Changes |
|---|---|
| `Otel.SDK.Configuration` | Added `maybe_put_metrics_env/1` and metric-specific parsers |

## Compliance

- [Metrics SDK](../compliance.md)
  * ExemplarFilter configuration SHOULD follow the environment variable specification — L1124
