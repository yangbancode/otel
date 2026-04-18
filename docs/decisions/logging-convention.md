# Logging Convention

## Question

Does the SDK emit its own diagnostic messages for spec SHOULD/MUST-log
requirements?

## Decision

**We only log for spec MUST requirements. SHOULD-level log
requirements are not implemented.**

### Rationale

The OpenTelemetry specification has SHOULD-log clauses at several
points (invalid tracer/meter/logger name, duplicate instrument
registration, dropped LogRecord attributes, view conflicts, unknown
advisory parameters, and others). We deliberately skip them for
three reasons:

1. **Happy-path policy.** The project assumes callers provide valid
   input at every API boundary (`code-conventions.md`). Defensive
   logging for SHOULD-violations is defensive code in disguise.
2. **Spec inconsistency.** SHOULD clauses across signals contradict
   each other (Trace API: log + coerce name to empty string; Metrics/
   Logs SDK: log + keep original invalid value). Skipping all of
   them produces internally consistent behavior across signals.
3. **Noop conflicts.** `metrics/noop.md` L63-64 and `logs/noop.md`
   L33-35 forbid any log output for any Noop operation. Implementing
   the SDK-side SHOULD-log then requires gating on "is SDK present?",
   which leaks SDK knowledge into the API layer.

### What about spec MUST-log?

We track spec MUST-log points in `compliance.md` as potential future
work. As of now the only known MUST-log requirement is
`sdk-environment-variables.md` L120 (Invalid `OTEL_TRACES_SAMPLER_ARG`).
Environment-variable parsing lives outside the current code scope, so
no active log call is required.

### Unchecked SHOULD-log items in `compliance.md`

The following compliance rows are marked `[ ]` with the annotation
`SHOULD not implemented per happy-path policy`:

- `trace/api.md` L129 — Invalid tracer name SHOULD be logged
- `metrics/sdk.md` L133 — Invalid meter name SHOULD be logged
- `logs/sdk.md` L81 — Invalid logger name SHOULD be logged
- `metrics/sdk.md` L942 — Duplicate instrument registration SHOULD warn
- `metrics/sdk.md` L962 — Instrument name SHOULD be validated
- `metrics/sdk.md` L965 — Invalid instrument name SHOULD emit error
- `metrics/sdk.md` L985 — Instrument advisory parameters SHOULD be validated
- `metrics/sdk.md` L986 — Invalid advisory parameter SHOULD emit error
- `logs/sdk.md` L345 — LogRecord attribute drop SHOULD warn
- `common/README.md` L284 — Attribute truncation MAY warn (already MAY, skipped trivially)

### When we do use Elixir `Logger`

If a future requirement adds a MUST-log call site, we use
`require Logger` + `Logger.warning("message")` — Elixir's
compile-time macro captures `:mfa`, `:file`, `:line`, `:application`
as metadata automatically. The message body carries only the message
text; it MUST NOT repeat module or function names (those duplicate
the auto-captured metadata). No custom metadata keys (no `:domain`,
no `:component`) — OTel semantic conventions define no standard key
for "internal component category" and adding one would introduce
forward-compat noise when logs are OTLP-exported.

### Comparison with opentelemetry-erlang

The reference implementation uses `?LOG_WARNING` at a handful of
call sites (invalid name, duplicate instrument, dropped attributes).
We originally mirrored that pattern and have now stepped back from
it in favor of the strict happy-path approach. This is a deliberate
divergence documented here.

## Compliance

No compliance checkboxes — this is a project-internal convention.
The spec-mandated Noop no-log rule is trivially satisfied because
we emit no logs at all from OTel-internal code.
