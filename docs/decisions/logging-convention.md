# Logging Convention

## Question

How does the SDK emit its own diagnostic messages? How to allow users to filter OTel-internal logs?

## Decision

### Use Erlang `:logger` with domain metadata

All internal log messages use Erlang's `:logger` with a `domain` metadata field set to `[:otel]`. This allows users to filter OTel logs without affecting application logs.

```elixir
:logger.warning("exporter timeout", %{domain: [:otel]})
```

### Domain hierarchy

Domains form a list-based hierarchy. `:logger_filters.domain/2` with `:sub` matches all sub-domains.

| Domain | Scope |
|---|---|
| `[:otel]` | All OTel internal logs |
| `[:otel, :trace]` | Trace-related logs |
| `[:otel, :metrics]` | Metrics-related logs |
| `[:otel, :export]` | Exporter logs |

Currently all logs use `[:otel]`. Sub-domains will be introduced as the SDK grows.

### User filtering

```elixir
# Hide all OTel logs
:logger.add_handler_filter(:default, :otel_filter,
  {&:logger_filters.domain/2, {:stop, :sub, [:otel]}})

# Show only OTel logs
:logger.add_handler_filter(:default, :otel_only,
  {&:logger_filters.domain/2, {:log, :sub, [:otel]}})
```

### Log levels

| Level | Usage |
|---|---|
| `error` | Unexpected internal failures (crashed callback, ETS corruption) |
| `warning` | Operational issues (invalid name, exporter timeout, dropped spans) |
| `info` | Lifecycle events (SDK started, exporter initialized) |
| `debug` | Diagnostic info (configuration applied, sampler decisions) |

### Comparison with opentelemetry-erlang

opentelemetry-erlang uses `?LOG_WARNING("message")` macros without domain metadata. Users cannot selectively filter OTel logs. Our approach is an improvement.

## Compliance
