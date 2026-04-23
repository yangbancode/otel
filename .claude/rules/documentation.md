## Documentation Conventions

For modules that implement a published specification (OTel, W3C
Trace Context, W3C Baggage, OTLP, etc.), documentation must make
**who calls this** and **why** visible during code review. Modules
with no spec mapping (internal SDK helpers, macro modules, etc.)
follow standard Elixir conventions without these rules.

See `apps/otel_api/lib/otel/api/trace/tracestate.ex` for a
canonical example of the format below.

### Tier classification

Every public function in `apps/otel_api/lib/` belongs to one of
three tiers, indicated by a bold marker on the first line of its
`@doc`. Elixir's visibility is binary (`def`/`defp`), so the
tier system is documentation-only — it does not enforce access
control but makes the audience explicit.

| Tier | Marker | Consumer |
|---|---|---|
| 1 | `**Application**` | Application code that instruments itself with OTel |
| 2 | `**SDK**` | SDK implementations (`otel_sdk` and third-party SDKs) |
| 3 | `**Internal**` | `otel_api` cross-module helpers (use `@doc false` + `#` comment) |

The marker carries secondary classification in parentheses — the
spec MUST/SHOULD/MAY level, the W3C wire-format role, or a role
descriptor for non-spec functions:

    **Application** (OTel API MUST) — ...
    **Application** (W3C header parsing) — ...
    **Application** (Convenience) — ...
    **SDK** (OTel API MUST) — ...
    **SDK** (installation hook) — ...

### Tier 1 — Application

Functions that application developers call directly to instrument
their code. Examples: `Span.set_attribute/3`, `Tracer.start_span/4`,
`Baggage.set_value/3`, all instrument facades (`Counter.add/3`
etc.), propagator `inject/3` / `extract/3`.

Recognised parenthetical descriptors:

- `(OTel API MUST)` / `(OTel API SHOULD)` / `(OTel API MAY)` —
  function whose behaviour the OTel spec defines at the
  corresponding strength.
- `(W3C header serialization)` / `(W3C header parsing)` — W3C
  wire-format encoder/decoder. Still Application-tier because
  apps can legitimately call them (logging, debugging, custom
  serializers).
- `(W3C format predicate)` — W3C format validator (e.g.
  `lowercase_hex?/1`).
- `(Convenience)` — project-added convenience for app
  developers, not in any spec (e.g. `TraceState.new/0`,
  `Event.new/3`, `Status.new/2`).

Example:

```elixir
@doc """
**Application** (OTel API MUST) — "Add Event"
(`trace/api.md` L525-L557).

Records an event on the span. The caller constructs the
`Event` via `Otel.API.Trace.Event.new/3` ...
"""
@spec add_event(span_ctx :: SpanContext.t(), event :: Event.t()) :: :ok
def add_event(span_ctx, event), do: ...
```

### Tier 2 — SDK

Functions that SDK implementations call, register with, or
implement. Application code typically does not call these — they
exist to let an SDK plug into the API layer.

Recognised parenthetical descriptors:

- `(OTel API MUST)` / `(OTel API SHOULD)` / `(OTel API MAY)` —
  for `@callback` declarations that the SDK must implement. The
  behaviour is spec-defined but the concrete implementation is
  the SDK's responsibility.
- `(installation hook)` — for functions the SDK calls during
  its `init/1` to register itself with the API layer (e.g.
  `TracerProvider.set_provider/1`, `Span.set_module/1`).
- `(Noop implementation)` — for `@impl true def` in the
  built-in Noop modules (`Tracer.Noop`, `Meter.Noop`,
  `Logger.Noop`, `TextMap.Noop`). Noop IS a degenerate SDK, so
  its callback implementations are SDK-tier.
- `(SDK helper)` — for pure utilities that SDK implementations
  use internally (e.g. `Instrument.downcased_name/1`,
  `Instrument.default_temporality_mapping/0`). Not called by
  application code, but not an `@callback` either.

Example (`@callback`):

```elixir
@doc """
**SDK** (OTel API MUST) — "Create a new Span"
(`trace/api.md` L193-L195).

Starts a new span and returns its `SpanContext`. Implementations
receive the parent context, the tracer handle, the span name,
and start options.
"""
@callback start_span(
            ctx :: Otel.API.Ctx.t(),
            tracer :: t(),
            name :: String.t(),
            opts :: Otel.API.Trace.Span.start_opts()
          ) :: Otel.API.Trace.SpanContext.t()
```

Example (installation hook):

```elixir
@doc """
**SDK** (installation hook) — Registers the given
`{module, state}` tuple as the global TracerProvider.

The SDK TracerProvider calls this from its `init/1` with
`{__MODULE__, server_ref}`; `module` must implement the
`Otel.API.Trace.TracerProvider` behaviour.
"""
@spec set_provider(provider :: t()) :: :ok
def set_provider({_module, _state} = provider), do: ...
```

Example (Noop implementation):

```elixir
@doc """
**SDK** (Noop implementation) — `start_span/4` no-op per
`trace/api.md` §"Behavior in the absence of an installed SDK"
(L860-L874).

Returns the parent's SpanContext when present; otherwise an
empty non-recording SpanContext.
"""
@impl true
def start_span(ctx, _tracer, _name, _opts), do: ...
```

### Tier 3 — Internal

Functions used across `otel_api` modules but not intended for
SDK or application consumption. These should be rare — if a
function is only called from within its own module, use `defp`
instead.

Convention:

- `@doc false` — explicitly hide from ExDoc. Do not write a
  visible `@doc`.
- `# Internal: ...` comment above the function describing why
  it is internal and which `otel_api` modules call it.
- Keep the `@spec` — Dialyzer still benefits from it.
- Do **not** list the function in the module's `## Public API`
  table.

Example:

```elixir
# Internal: cross-module helper used by Otel.API.X and
# Otel.API.Y to build a shared cache key. Not part of the
# SDK or application interface.
@doc false
@spec build_key(name :: String.t(), scope :: map()) :: tuple()
def build_key(name, scope), do: {scope, String.downcase(name)}
```

### `@typedoc` — identify the type + spec location

Open with a short noun phrase and the spec section reference:

```elixir
@typedoc """
A W3C TraceState key (spec §3.3.1.3.1, Level 2).

Must begin with a lowercase letter or digit, followed by up to
255 characters from `[a-z0-9_\\-*/@]`.

Invalid keys are silently dropped by mutating operations.
"""
@type key :: String.t()
```

Follow with bullets or prose describing the accepted shape, then
notes on validation behaviour.

### `@moduledoc` — describe + classify

Structure:

1. Short description of what the module is, with top-level spec
   reference (e.g. "W3C Trace Context `tracestate` field
   (spec §3.3)").
2. `## Public API` table mapping each function to its tier +
   descriptor. Tier 3 (`@doc false`) functions are omitted.
3. `## References` section with spec file paths.

```markdown
## Public API

| Function | Role |
|---|---|
| `get/2`, `add/3`, `update/3`, `delete/2` | **Application** (OTel API MUST) |
| `encode/1`, `decode/1` | **Application** (W3C header serialization/parsing) |
| `valid_key?/1`, `valid_value?/1` | **Application** (W3C format predicate) |
| `new/0`, `empty?/1` | **Application** (Convenience) |

## References

- W3C Trace Context: <https://www.w3.org/TR/trace-context/>
- OTel Trace API: `opentelemetry-specification/specification/trace/api.md`
```

### Source ordering

Arrange functions in the source file by tier, then by
sub-descriptor strength. This way readers see the tier from
source structure alone, reinforced by the first-line marker.

1. **Tier 1 — Application**, in order:
   - `(OTel API MUST)`
   - `(OTel API SHOULD)`
   - `(OTel API MAY)`
   - `(W3C header serialization)` / `(W3C header parsing)`
   - `(W3C format predicate)`
   - `(Convenience)`
2. **Tier 2 — SDK**, in order:
   - `@callback` declarations (`(OTel API MUST/SHOULD/MAY)`)
   - `(installation hook)`
   - `(Noop implementation)` (in Noop modules only)
   - `(SDK helper)`
3. **Tier 3 — Internal** (`@doc false`)
4. **Private functions** (`defp`)

### Constants and module attributes

Inline comments for spec-derived constants cite the section:

```elixir
# W3C §3.3.1.1: "There can be a maximum of 32 list-members in a list."
@max_members 32

# W3C §3.3.1.5 tracestate Limits: vendors SHOULD propagate at least
# 512 characters of a combined header.
@max_header_bytes 512
```

### Spec paths

Reference spec files by their path inside the respective spec
repo, omitting the `references/` prefix. Canonical forms:

```
opentelemetry-specification/specification/trace/api.md
w3c-trace-context/spec/20-http_request_header_format.md
w3c-baggage/baggage/HTTP_HEADER_FORMAT.md
opentelemetry-proto/opentelemetry/proto/trace/v1/trace.proto
```

Not:

```
references/opentelemetry-specification/specification/trace/api.md
```

### Spec sources in `references/`

When writing spec citations, verify section numbers against the
local copy of the spec:

| Spec | Path | Pin |
|---|---|---|
| OTel Specification | `references/opentelemetry-specification/` | latest tag in use |
| W3C Trace Context | `references/w3c-trace-context/` | `level-2` branch (per OTel `context/api-propagators.md` MUST) |
| W3C Baggage | `references/w3c-baggage/` | `main` (still Working Draft, no REC) |
| OTLP Proto | `references/opentelemetry-proto/` | — |
| Semantic Conventions | `references/semantic-conventions/` | — |

### Migration from pre-tier markers

The convention above supersedes earlier marker schemes. Codebase
migration happens in a follow-up pass; this table is the
authoritative mapping:

| Old marker | New marker |
|---|---|
| `**OTel API MUST**` | `**Application** (OTel API MUST)` on facade/API functions, `**SDK** (OTel API MUST)` on `@callback` declarations |
| `**OTel API SHOULD**` | `**Application** (OTel API SHOULD)` / `**SDK** (OTel API SHOULD)` — same rule |
| `**OTel API MAY**` | `**Application** (OTel API MAY)` / `**SDK** (OTel API MAY)` |
| `**W3C header serialization**` | `**Application** (W3C header serialization)` |
| `**W3C header parsing**` | `**Application** (W3C header parsing)` |
| `**W3C format predicate**` | `**Application** (W3C format predicate)` |
| `**OTel convenience**` | `**Application** (OTel API MAY)` — same as spec MAY now |
| `**Local helper** (not in spec)` | Contextual — either `**Application** (Convenience)`, `**SDK** (installation hook / SDK helper)`, or `@doc false` + `# Internal:` comment |

When in doubt between `**Application** (Convenience)` and
`**SDK** (SDK helper)`, check actual callsites — if the only
library callers are under `apps/otel_sdk/lib/`,
`apps/otel_otlp/lib/`, or
`apps/otel_logger_handler/lib/`, it is `**SDK**`. If application
code plausibly calls it, it is `**Application**`.
