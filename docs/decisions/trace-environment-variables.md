# Trace Environment Variables

## Question

How to parse and apply OTEL_* environment variables for Traces configuration (OTEL_TRACES_SAMPLER, OTEL_TRACES_EXPORTER, OTEL_BSP_*, OTEL_SPAN_*, etc.)?

## Decision

### Module: `Otel.SDK.Configuration`

Location: `apps/otel_sdk/lib/otel/sdk/configuration.ex`

Internal module that reads OS environment variables and merges them with Application config and defaults.

### Priority

```
OS environment variables > Application config > defaults
```

Follows opentelemetry-erlang's `otel_configuration:merge_with_os/1` pattern.

### Supported Variables

#### Sampler

| Variable | Values | Default |
|---|---|---|
| `OTEL_TRACES_SAMPLER` | `always_on`, `always_off`, `traceidratio`, `parentbased_always_on`, `parentbased_always_off`, `parentbased_traceidratio` | `parentbased_always_on` |
| `OTEL_TRACES_SAMPLER_ARG` | probability float for ratio samplers | `1.0` |

#### Span Limits

| Variable | Default |
|---|---|
| `OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT` | 128 |
| `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT` | infinity |
| `OTEL_SPAN_EVENT_COUNT_LIMIT` | 128 |
| `OTEL_SPAN_LINK_COUNT_LIMIT` | 128 |
| `OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT` | 128 |
| `OTEL_LINK_ATTRIBUTE_COUNT_LIMIT` | 128 |

#### Batch Span Processor

| Variable | Default |
|---|---|
| `OTEL_BSP_SCHEDULE_DELAY` | 5000 ms |
| `OTEL_BSP_EXPORT_TIMEOUT` | 30000 ms |
| `OTEL_BSP_MAX_QUEUE_SIZE` | 2048 |
| `OTEL_BSP_MAX_EXPORT_BATCH_SIZE` | 512 |

### Parsing Rules

- Empty values treated as unset
- Sampler names are case-insensitive
- Unparseable numeric values default to 0 (int) or infinity (value length)
- Unknown sampler names are ignored (returns nil)

### Integration

Called in `Otel.SDK.Application.start/2` before starting the supervision tree.

## Compliance

- [Compliance](../compliance.md)
  * Environment Variables — General SDK Configuration, Batch Span Processor, Span Limits
