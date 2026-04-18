# Logging Convention

## Question

How does the SDK emit its own diagnostic messages?

## Decision

### When to log

Only log when the OTel spec explicitly requires it (SHOULD/MUST log). Do not add discretionary logs. Known spec-required log points:

| Spec location | Trigger | Strength |
|---|---|---|
| error-handling.md L52 | Suppressed error | SHOULD |
| common/README.md L284 | Attribute truncated/discarded (max 1x per record) | MAY |
| trace/api.md L129 | Invalid tracer name | SHOULD |
| trace/sdk.md L873 | Span limit exceeded (max 1x per span) | SHOULD |
| metrics/sdk.md L130 | Invalid meter name | SHOULD |
| logs/sdk.md L78 | Invalid logger name | SHOULD |
| logs/sdk.md L345 | LogRecord limit exceeded (max 1x per record) | SHOULD |
| sdk-environment-variables.md L72 | Invalid boolean environment variable | SHOULD |
| sdk-environment-variables.md L120 | Invalid OTEL_TRACES_SAMPLER_ARG | MUST |

### Noop path MUST NOT log

`metrics/noop.md` L63-64 and `logs/noop.md` L33-35 forbid the
MeterProvider and LoggerProvider from emitting any log output when no
SDK is registered. The `validate_name/1` helpers on both providers gate
the SHOULD-log on `get_provider() != nil`, so the SDK path follows
`api.md` L129 while the Noop path stays silent.

### Use Elixir `Logger`, not Erlang `:logger`

All internal diagnostics go through Elixir's `Logger`:

```elixir
require Logger

Logger.warning("invalid meter name nil, using empty string")
```

`Logger.warning/1` is a compile-time macro that captures the call site
as `:mfa` metadata (`{Module, function, arity}`), plus `:file`, `:line`,
and `:application`. These are available to formatters and log-collection
tools without us repeating the information in the message text.

The Erlang `:logger.warning/1,2` function form does not capture caller
metadata and should be avoided in OTel-internal code.

### Message body carries only the message

The first argument of `Logger.warning` is a single natural-language
sentence describing what happened and what the SDK did about it. It
MUST NOT restate the module name, function name, or any other piece of
information that `Logger` already captures as metadata.

| Form | Rule |
|---|---|
| `"invalid meter name nil, using empty string"` | ✅ message only |
| `"invalid meter name #{inspect(name)}, using empty string"` | ✅ interpolation OK |
| `"MeterProvider: invalid meter name nil, using empty string"` | ❌ module name duplicates `:mfa` metadata |
| `"[metrics] invalid meter name"` | ❌ category tag belongs in metadata, not the message |

### No custom metadata keys

We deliberately do not pass `:domain` or any other custom metadata
beyond what `Logger` auto-captures. OpenTelemetry's own semantic
conventions have no standard key for "OTel-internal component category",
and the Erlang-specific `:domain` convention does not survive cleanly
through an OTLP export. Keeping the metadata footprint minimal avoids
forward-compatibility surprises. If callers want to filter OTel logs
they can match on the `:mfa` metadata's module.

### Log levels

| Level | Usage |
|---|---|
| `error` | Unexpected internal failures (crashed callback, ETS corruption) |
| `warning` | Operational issues (invalid name, exporter timeout, dropped spans) |
| `info` | Lifecycle events (SDK started, exporter initialized) |
| `debug` | Diagnostic info (configuration applied, sampler decisions) |

### Comparison with opentelemetry-erlang

opentelemetry-erlang uses `?LOG_WARNING("message")` macros, which also
capture caller metadata at compile time and pass only the message body.
Our approach mirrors that pattern in Elixir.

## Compliance

No compliance checkboxes — this is a project-internal convention, not
a spec mandate. The only spec-driven obligation is the Noop no-log rule
tracked in `docs/compliance.md` under the Metrics Noop and Logs Noop
sections.
