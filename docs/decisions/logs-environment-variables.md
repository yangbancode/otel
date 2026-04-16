# Logs Environment Variables

## Question

How to parse and apply OTEL_* environment variables for Logs configuration (OTEL_LOGS_EXPORTER, OTEL_EXPORTER_OTLP_LOGS_ENDPOINT, etc.)?

## Decision

### Implementation

Logs environment variables are parsed in `Otel.SDK.Configuration.maybe_put_logs_env/1`, following the same pattern as Traces and Metrics env vars. Results are stored under the `:logs` key in the merged config map.

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `OTEL_LOGS_EXPORTER` | `otlp` | Logs exporter: `otlp`, `console`, `none` |
| `OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT` | 128 | Max attributes per LogRecord |
| `OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT` | no limit | Max string value length |
| `OTEL_BLRP_SCHEDULE_DELAY` | 1000 ms | Batch processor export interval |
| `OTEL_BLRP_EXPORT_TIMEOUT` | 30000 ms | Batch processor export timeout |
| `OTEL_BLRP_MAX_QUEUE_SIZE` | 2048 | Batch processor max queue size |
| `OTEL_BLRP_MAX_EXPORT_BATCH_SIZE` | 512 | Batch processor max batch size |

OTLP exporter env vars (`OTEL_EXPORTER_OTLP_LOGS_*`) are handled by the `Otel.Exporter.OTLP.Logs` module directly.

### Config Structure

```elixir
%{
  logs: %{
    exporter: :otlp | :console | :none,
    log_record_limits: %Otel.SDK.Logs.LogRecordLimits{...},
    blrp: %{
      scheduled_delay_ms: integer(),
      export_timeout_ms: integer(),
      max_queue_size: integer(),
      max_export_batch_size: integer()
    }
  }
}
```

## Compliance

No direct compliance items — environment variable support follows the SDK configuration specification.
