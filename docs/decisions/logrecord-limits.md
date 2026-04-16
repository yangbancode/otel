# LogRecord Limits

## Question

How to implement LogRecord attribute limits on BEAM? Attribute count and value length limits, configuration via LoggerProvider?

## Decision

### Module

| Module | Location | Description |
|---|---|---|
| `Otel.SDK.Logs.LogRecordLimits` | `apps/otel_sdk/lib/otel/sdk/logs/log_record_limits.ex` | Limits struct and apply function |

### Limits

| Limit | Default | Description |
|---|---|---|
| `attribute_count_limit` | 128 | Max attributes per LogRecord |
| `attribute_value_length_limit` | `:infinity` | Max string/byte array value length |

### Behavior

- Attributes beyond count limit are discarded
- String values exceeding length limit are truncated
- Strings in lists are also truncated
- Non-string values (integers, floats, booleans) are never truncated
- A warning is logged at most once per LogRecord when attributes are discarded
- `dropped_attributes_count` is attached to the log record for exporters

### Configuration

Limits are configured via `LoggerProvider` as part of the `log_record_limits` config key. The `LogRecordLimits` struct is passed through to each Logger and applied during `build_log_record`.

## Compliance

- [Logs SDK](../compliance.md)
  * LogRecord Limits — L323, L326, L331, L345, L347
