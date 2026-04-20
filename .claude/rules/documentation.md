## Documentation Conventions

For modules that implement a published specification (OTel, W3C
Trace Context, W3C Baggage, OTLP, etc.), documentation must make
spec alignment visible during code review. Modules with no spec
mapping (internal SDK helpers, macro modules, etc.) follow
standard Elixir conventions without these rules.

See `apps/otel_api/lib/otel/api/trace/tracestate.ex` for a
canonical example of the format below.

### `@doc` — role-first for spec-aligned modules

Each public function's `@doc` opens with a **bold role marker** on
the first line:

```elixir
@doc """
**OTel API MUST** — "Add a new key/value pair" (`trace/api.md` TraceState).

Prepends a new `{key, value}` entry to the list ...
"""
```

Recognised role markers:

- **`**OTel API MUST**`** — operations the OTel spec mandates.
  Include the operation name (from the spec section heading) and
  the spec file path.
- **`**W3C header serialization**`** / **`**W3C header parsing**`** —
  functions implementing a W3C wire format. Cite the W3C section.
- **`**W3C format predicate**`** — validators for a W3C-defined
  format. Cite the W3C section.
- **`**Local helper** (not in spec)`** — conveniences added by this
  project, not mandated by any spec.

The body after the first line describes behaviour and edge cases.
No footer markers (e.g. `*Convenience.*`) — the role is the first
line.

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
   reference (e.g. "W3C Trace Context `tracestate` field (spec §3.3)").
2. `## Public API` table mapping each function to its role marker.
3. `## References` section with spec file paths.

```markdown
## Public API

| Function | Role |
|---|---|
| `get/2`, `add/3`, `update/3`, `delete/2` | **OTel API MUST** |
| `encode/1`, `decode/1` | **W3C header serialization** |
| `valid_key?/1`, `valid_value?/1` | **W3C format predicate** |
| `new/0`, `size/1` | **Local helper** (not in spec) |

## References

- W3C Trace Context: <https://www.w3.org/TR/trace-context/>
- OTel Trace API: `opentelemetry-specification/specification/trace/api.md`
```

### Source ordering

Arrange functions in the source file by role, in this order:

1. **OTel API MUST** operations
2. **W3C header serialization / parsing** helpers
3. **W3C format predicates**
4. **Local helpers** (not in spec)
5. Private functions (`defp`)

Position + first-line marker reinforce each other; readers see
spec status from source structure alone.

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

Reference spec files by their path inside the respective spec repo,
omitting the `references/` prefix. Canonical forms:

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
