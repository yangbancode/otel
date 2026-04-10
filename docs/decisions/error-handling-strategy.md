# Error Handling Strategy

## Question

How does the SDK handle errors without crashing instrumented applications? What patterns ensure the OTel mandate of "never crash the host"?

## Decision

### Principle

The OTel spec mandates: **lose telemetry rather than crash the host application.** On BEAM, this translates to a layered defense:

1. Public API functions never raise — they return safe defaults on bad input
2. Supervised background processes restart on failure
3. Internal errors are logged via Erlang `:logger`, never propagated to callers

### Layer 1: Public API Boundary

All public API functions use pattern matching and guards to validate input. Invalid input returns a safe default or no-op value without raising.

```elixir
# Good — returns :invalid on bad input
def get(trace_state, key) when is_binary(key), do: ...
def get(_trace_state, _key), do: :invalid

# Good — silently ignores invalid operations
def set_attribute(span, _key, _value) when span.ended?, do: span
```

For callbacks from user code (e.g., custom samplers, exporters), wrap with `try/rescue`:

```elixir
try do
  callback.(args)
rescue
  e ->
    :logger.error("callback failed", %{error: e, module: __MODULE__})
    default_value
end
```

### Layer 2: Supervision

Background processes (exporters, processors, batch workers) run under OTP supervisors with `:permanent` restart strategy. A crashed exporter restarts automatically — telemetry may be lost during restart, but the host application is unaffected.

Supervisor hierarchy isolates failures:

- Exporter crash does not affect span processor
- Processor crash does not affect TracerProvider
- No SDK failure propagates to user application processes

### Layer 3: Internal Logging

All suppressed errors are logged via Erlang `:logger` with structured metadata:

```elixir
:logger.warning("exporter endpoint unreachable",
  %{module: __MODULE__, endpoint: url, reason: reason})
```

Log levels:
- `error` — unexpected internal failures (crashed callback, ETS corruption)
- `warning` — operational issues (exporter timeout, dropped spans due to queue full)
- `debug` — diagnostic info (configuration applied, sampler decision)

SDK logs use a dedicated logger domain `[:otel]` so users can filter them:

```elixir
# User can filter OTel logs
:logger.add_handler_filter(:default, :otel_filter,
  {&:logger_filters.domain/2, {:stop, :sub, [:otel]}})
```

### Fail-Fast at Initialization

The spec allows failing fast during initialization. The SDK raises on startup for:

- Invalid configuration values that cannot have safe defaults (e.g., negative batch timeout)
- Missing required dependencies

This happens during `Application.start/2`, before any user code runs.

### No Custom Error Handler Callback

The spec says SDK implementations MUST allow users to change error handling behavior. On BEAM, Erlang's `:logger` already provides this — users can add custom handlers, filters, and formatters. No separate error handler callback API is needed.

## Compliance

- [API Propagators](../compliance/api-propagators.md)
  * Operations — L83, L84, L93, L102, L102
- [Trace API](../compliance/trace-api.md)
  * TraceState — L284, L291, L292, L293, L294, L295
- [Logs SDK](../compliance/logs-sdk.md)
  * OnEmit — L397, L409
