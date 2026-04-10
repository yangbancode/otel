# Logging Convention

## Question

How does the SDK emit its own diagnostic messages? How to allow users to filter OTel-internal logs?

## Decision

### When to log

Only log when the OTel spec explicitly requires it (SHOULD/MUST log). Do not add discretionary logs. Known spec-required log points:

| Spec location | Trigger |
|---|---|
| trace/api.md L129 | Invalid tracer name |
| error-handling.md L52 | Suppressed error |
| trace/sdk.md L873 | Attribute truncation/discard due to limits |
| sdk-environment-variables.md L72 | Invalid environment variable value |

### Use Erlang `:logger` with domain metadata

All internal log messages use Erlang's `:logger` with a `domain` metadata field. This allows users to filter OTel logs without affecting application logs.

```elixir
:logger.warning("invalid tracer name", %{domain: [:otel, :trace]})
```

### Domain hierarchy

Domains form a list-based hierarchy. `:logger_filters.domain/2` with `:sub` matches all sub-domains.

| Domain | Scope |
|---|---|
| `[:otel]` | All OTel internal logs |
| `[:otel, :trace]` | Trace API/SDK logs |
| `[:otel, :metrics]` | Metrics API/SDK logs |
| `[:otel, :logs]` | Logs API/SDK logs |
| `[:otel, :export]` | Exporter logs |
| `[:otel, :config]` | Configuration/environment variable logs |

### User filtering

```elixir
# Hide all OTel logs
:logger.add_handler_filter(:default, :otel_filter,
  {&:logger_filters.domain/2, {:stop, :sub, [:otel]}})

# Show only OTel trace logs
:logger.add_handler_filter(:default, :otel_trace_only,
  {&:logger_filters.domain/2, {:log, :sub, [:otel, :trace]}})
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
