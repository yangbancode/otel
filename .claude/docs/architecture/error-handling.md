# Error Handling

## Question

How should the OpenTelemetry SDK handle failures — malformed external data,
IO errors, user-provided callback crashes, programmer mistakes, and runtime
faults — without crashing the host application, while meeting the spec's
"MUST NOT throw" guarantees?

## Decision

**Deferred to the Finalization phase.** Until then, the project follows the
**happy-path-only discipline** captured in `.claude/rules/code-conventions.md`:

- Every function call is assumed to succeed.
- `try/catch/rescue` is not used (single exception: `Trace.with_span/5`).
- `{:ok, value} | :error` tuples are not introduced.
- Silent fallbacks on malformed external data are not written.
- Defensive nil/type checks outside of spec-mandated behavior are not added.

### Why defer

1. **Full call graph needed.** Error-handling decisions depend on knowing
   every callback boundary, exporter retry point, and processor interaction.
   Committing early produces an inconsistent patchwork.
2. **Spec MUST violations are already present.** Temporarily violating more
   of them in exchange for a simpler intermediate codebase is acceptable
   before the final pass.
3. **Policy quality.** A single unified decision — rather than ad-hoc
   choices scattered across PRs — gives the project a coherent surface.
4. **Finalization scope.** Hex.pm publishing of runtime packages (SDK,
   exporters) is gated on this decision.

### What the final policy will need to cover

These are the known axes; the actual decision is made in Finalization.

- **External data parsing** (propagator extract, tracestate decode, OTLP
  payload, config env vars). Spec: `context/api-propagators.md` L101-103
  "MUST NOT throw an exception and MUST NOT store a new value".
- **Public API entry points** under invalid user input. Spec:
  `error-handling.md` L15 "MUST provide safe defaults for missing or
  invalid arguments".
- **User-provided callbacks** (Sampler.should_sample, Exporter.export,
  custom Propagators). Spec: `error-handling.md` L24 "API methods that
  accept external callbacks MUST handle all errors".
- **Internal SDK machinery** (batch processor, reader, span storage).
  Spec: `error-handling.md` L19 "MUST NOT throw unhandled exceptions for
  errors in their own operations".
- **Exporter IO** (network, transport, retry). Spec: `trace/sdk.md`
  L1159-1164 "SDK's Span Processors SHOULD NOT implement retry logic,
  as the required logic is likely to depend heavily on the specific
  protocol and backend".
- **Exception recording** (`Span.record_exception`, `Span.with_span`).
  Spec: `trace/exceptions.md` L27-40 template — record then rethrow.
- **Logging and telemetry emission** for suppressed errors. Spec:
  `error-handling.md` L52 "the library SHOULD log the error using
  language-specific conventions".
- **User-overridable error handler** (spec L57 MUST).

### References (for future finalization)

- `opentelemetry-specification/specification/error-handling.md`
- `opentelemetry-erlang` patterns: guard + catch-all (API), try/catch
  (init), let-it-crash (runtime).

## Spec references

Once the finalization pass is complete, the following spec clauses
will be revisited:

- `error-handling.md` L13, L15, L18, L19, L24, L34, L52, L57.
- Per-signal MUST NOT throw requirements (Propagator Extract, SpanProcessor
  OnStart/OnEnd, LogRecordProcessor OnEmit, MetricReader Collect, etc.).
- Per-signal SHOULD log requirements (name validation, advisory parameter
  conflicts, attribute limits, etc.).
