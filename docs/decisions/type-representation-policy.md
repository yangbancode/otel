# Type Representation Policy

## Question

What criteria govern the choice between native types, `@type` aliases,
`@opaque` types, and `defstruct` modules when representing an OpenTelemetry
spec concept in Elixir?

Until now, each new spec entity has been modelled in whatever form felt most
natural at the moment: `SpanContext` became a struct, `AnyValue` and
`Attribute` became `@type` aliases, and primitive identifiers like trace IDs
were left as bare `non_neg_integer()`. This has worked, but it leaves every
future entity — `Link`, `Event`, `Status`, `LogRecord`, `Measurement`,
`Instrument`, `SeverityNumber`, and more — without a shared rule for how to
translate the spec shape into Elixir. This Decision establishes that shared
rule.

## Decision

### The 4-tier decision tree

For every spec concept, walk this tree top-down. Stop at the first YES.

```
Q1. Does the spec concept have multiple named fields with distinct
    semantic meanings?
    YES → defstruct
    NO  → Q2

Q2. Does the spec define this as a bounded integer with a small
    explicit range?
    YES → range literal type (e.g. `0..24`)
    NO  → Q3

Q3. Does Dialyzer need to distinguish this concept from its underlying
    primitive (i.e., identity semantics added on top of a native type)?
    YES → @opaque alias with constructor + validators
    NO  → Q4

Q4. Is the concept a union of primitives or a shape (like a map) that is
    either reused across modules OR carries non-trivial spec constraints?
    YES → @type alias
    NO  → use the native type directly
```

### Rationale for ordering

The tree is ordered from strongest to weakest signal so that the cheapest
tool wins whenever it fits.

- **Q1 first.** "Multiple named fields" is the clearest structural signal. A
  concept like `Link` (context + attributes) carries meaning in the *pairing*
  of fields, not in any single value — a struct is the only tool that
  preserves that pairing with compile-time field checks. Asking this first
  stops us from prematurely wrapping multi-field concepts in aliases or
  opaques that would then need a second refactor.
- **Q2 second.** Range literal types (`0..24`) are Dialyzer-native and cost
  nothing at runtime. When the spec pins an integer to a small range, a
  range literal expresses that constraint directly in the typespec; no
  constructor module, no `@opaque` boundary. Checking this before Q3 avoids
  reaching for the heavier `@opaque` tool when a one-line range literal
  already does the job.
- **Q3 third.** `@opaque` sits between range literals and structs in cost. It
  requires a defining module, a constructor, and caller discipline, but it
  buys cross-module Dialyzer discrimination on an otherwise-indistinguishable
  primitive. We use it only when that discrimination is the *only* thing
  needed — if named fields appear later, the answer is a struct, not an
  opaque wrapping a tuple.
- **Q4 last.** `@type` aliases capture shape (a union, a map schema) without
  adding identity or field semantics. They are the default for non-trivial
  types that are reused across modules. Placing this last ensures we only
  define an alias when the shape is genuinely non-trivial; otherwise the
  native type stands on its own.

### Entity catalog

Every OTel spec entity this project handles today, classified under the
policy above. Rows for not-yet-implemented entities record the intended
classification; field selection is left to their own future Decisions.

| Entity | Tool | Rationale |
|---|---|---|
| `LogRecord` | `defstruct` | Named fields (timestamp, body, attributes, severity_number, ...) |
| `Link` | `defstruct` | Named fields (context, attributes) |
| `Event` | `defstruct` | Named fields (name, timestamp, attributes) |
| `Status` | `defstruct` | Named fields (code, description) |
| `Measurement` | `defstruct` | Named fields (value, attributes) |
| `Instrument` | `defstruct` | Named fields (name, kind, unit, description) |
| `SpanContext` | `defstruct` | Named fields (trace_id, span_id, trace_flags, tracestate, is_remote) — already a struct, see [spancontext-struct.md](spancontext-struct.md) |
| `SeverityNumber` | range literal `0..24 \| nil` | Bounded integer with a small explicit range (spec defines 1..24 with 0 as UNSPECIFIED) |
| `TraceId` | `@opaque` on `non_neg_integer()` | Identity semantics on a 128-bit primitive; must be distinguishable from other integers at module boundaries |
| `SpanId` | `@opaque` on `non_neg_integer()` | Identity semantics on a 64-bit primitive; must be distinguishable from `TraceId` and other integers |
| `AnyValue` | `@type` alias (union) | Tagged union of primitives + recursive containers; reused across signals |
| `Attribute.value` | `@type` alias (union) | `AnyValue` subset; reused across spans, log records, metrics |
| `Attribute.attributes` | `@type` alias (map shape) | Keyed collection; map guarantees unique keys per spec |
| `severity_text` | native `String.t()` | Generic string with no additional spec constraints |
| `timestamp` | native `integer()` | Conventional Unix-epoch nanoseconds; no BEAM-level distinction needed |
| `event_name` | native `String.t()` | Generic string |

### When this policy applies

- All new entities introduced after this Decision MUST be run through the
  4-tier tree before implementation. The resulting choice is recorded in the
  entity's own Decision doc, citing this policy.
- Existing entities that do not match this policy are tracked in `.audit/`
  and migrated in dedicated PRs; they are not rewritten in unrelated feature
  work.
- The PR introducing this policy also introduces `TraceId` and `SpanId` as
  `@opaque` types — the first concrete application of Q3.

### Trade-offs accepted

- **Some spec entities stay as native types.** `severity_text`, `timestamp`,
  and `event_name` remain plain `String.t()` / `integer()`. Elixir's native
  types already express these concepts accurately; wrapping them would add
  ceremony with no Dialyzer or documentation benefit. We deliberately do not
  turn every spec noun into a module.
- **`@opaque` requires constructor discipline.** Callers outside the defining
  module must use `Otel.API.Trace.TraceId.new/1`, provided accessors, and
  encoders — not raw integer construction. This is a real cost: a caller who
  has a plain `non_neg_integer()` cannot simply pass it where a `TraceId` is
  expected without going through the constructor. We accept this cost
  because it is exactly what catches mix-ups like passing a `SpanId` where a
  `TraceId` is expected, which would otherwise be a silent integer swap.
- **Range literals are invisible at Dialyzer module boundaries.** Dialyzer
  treats `0..24` as just another integer when values flow across function
  boundaries. Choosing a range literal for `SeverityNumber` therefore does
  *not* provide the cross-module distinction that `@opaque` does. We accept
  this because severity numbers have no realistic confusability risk with
  other integers — they are not arguments to the same functions as trace IDs
  or span IDs.
- **Divergence from `opentelemetry-erlang` / `-java` / `-go`.** Those
  reference implementations use raw primitives almost everywhere (trace IDs
  and span IDs are bare integers or byte strings, severity numbers are bare
  ints). This project takes a more Elixir-native approach: use the right
  tool per concept, even when that means more modules than the reference
  implementations have. The benefit is Dialyzer-visible type safety on the
  identifiers that matter most.

### Relationship to other Decisions

- **Does not supersede any prior Decision.** The earlier
  [attribute-and-anyvalue-types.md](attribute-and-anyvalue-types.md)
  Decision is fully consistent with this policy: `AnyValue` and `Attribute`
  are Q4 results (`@type` aliases for a union and a map shape reused across
  signals). This policy reframes that earlier choice as a specific
  application of a general rule, rather than a one-off stylistic preference.
- **[spancontext-struct.md](spancontext-struct.md)** is a Q1 result — five
  named fields (`trace_id`, `span_id`, `trace_flags`, `tracestate`,
  `is_remote`) with distinct semantics make `defstruct` the only fit.
- **Future Decisions** for composite entities (`Link`, `Event`, `Status`,
  `LogRecord`, `Measurement`, `Instrument`) will cite this policy as their
  justification for choosing `defstruct`, and will focus their own prose on
  field selection and lifecycle rather than re-arguing the shape choice.

## Modules

Introduced in this PR as the first concrete application of Q3:

- `Otel.API.Trace.TraceId` — `@opaque` 128-bit trace identifier. Provides a
  constructor from a `non_neg_integer()` (`new/1`), a validity predicate
  (`valid?/1`, non-zero check), a 16-byte binary encoder (`to_bytes/1`),
  a 32-character lowercase hex encoder (`to_hex/1`), and an integer
  escape hatch for SDK bit arithmetic (`to_integer/1`).
- `Otel.API.Trace.SpanId` — `@opaque` 64-bit span identifier. Provides a
  constructor from a `non_neg_integer()` (`new/1`), a validity predicate
  (`valid?/1`, non-zero check), an 8-byte binary encoder (`to_bytes/1`),
  and a 16-character lowercase hex encoder (`to_hex/1`).

Both modules follow the policy's Q3 contract: callers outside the defining
module may not construct or inspect the underlying integer directly, and all
conversions go through the provided functions.

## Compliance

- [Trace API](../compliance.md)
  * SpanContext — binary 16-byte TraceId, binary 8-byte SpanId (satisfied by
    `TraceId.to_bytes/1` and `SpanId.to_bytes/1`)
  * Retrieving the TraceId and SpanId — 32-char hex TraceId, 16-char hex
    SpanId (satisfied by `TraceId.to_hex/1` and `SpanId.to_hex/1`)
