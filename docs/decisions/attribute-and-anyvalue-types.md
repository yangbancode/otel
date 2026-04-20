# Attribute and AnyValue Types

## Question

The OTel spec's [common concepts](../../references/opentelemetry-specification/specification/common/README.md)
define `AnyValue`, `Attribute`, `Attribute Collections`, and `Attribute
Limits` — concepts the rest of the API depends on (spans, log records,
instrumentation scope, resource). Until now the API referenced these inline
with loose types (e.g. `map() | [{String.t(), term()}]` on
`set_attributes/2`) and had no single source of truth for the shapes or
rationale. How should `otel_api` model them — in particular, how to
disambiguate `string` vs `byte array`, whether to accept atom keys, how to
satisfy the "MUST enforce unique keys" rule, and where attribute limits
live?

## Decision

### AnyValue module

`Otel.API.AnyValue` is a pure type-alias module — no struct, no wrapping, no
runtime validation. We chose aliases over structs to keep zero runtime
overhead and to mirror the style of `opentelemetry-erlang`, where `AnyValue`
is modelled as a tagged union of native terms.

The type definition:

```elixir
@type t ::
        String.t()
        | binary()
        | boolean()
        | integer()
        | float()
        | [t()]
        | %{String.t() => t()}
        | nil
```

Spec primitives map to Elixir types as follows:

| Spec primitive                    | Elixir type               |
|-----------------------------------|---------------------------|
| string                            | `String.t()`              |
| byte array                        | `binary()`                |
| boolean                           | `boolean()`               |
| signed 64-bit integer             | `integer()`               |
| IEEE 754 double                   | `float()`                 |
| array of AnyValue (heterogeneous) | `[t()]`                   |
| `map<string, AnyValue>`           | `%{String.t() => t()}`    |
| empty value                       | `nil`                     |

#### string vs byte array

OTLP distinguishes `string_value` from `bytes_value` at the wire level
(`common.proto` `AnyValue` oneof). Elixir represents both as `binary()`, so
both appear in the `t:t/0` union even though they collapse to the same BEAM
term. We resolve the split at **export time**, not at API ingest, using a
UTF-8 validity heuristic that mirrors `opentelemetry-erlang`'s
`otel_otlp_common:to_any_value/1`: valid UTF-8 → `string_value`, invalid →
`bytes_value`. A binary that is accidentally valid UTF-8 but was intended as
raw bytes will be emitted as a string; callers who need byte semantics on a
UTF-8-valid payload must rely on exporter-specific configuration. The
heuristic lives in the OTLP exporter, not in `otel_api`, keeping the API
free of transport concerns.

#### Integer range

The spec requires integers fit in a signed 64-bit range (`-2^63` through
`2^63 - 1`). Elixir's `integer()` is arbitrary precision; we do not encode
the 64-bit limit in the typespec. Range-literal typespecs hurt readability
without providing runtime enforcement — Dialyzer does not check numeric
ranges. Out-of-range values are an exporter concern, handled when the OTLP
encoder converts to `int64`.

#### Nesting and empty values

Arbitrary deep nesting of arrays and maps is permitted; `t:t/0` is recursive
through the `[t()]` and `%{String.t() => t()}` branches. An `AnyValue` of
`nil` represents the spec's "empty value" (language-specific; Elixir idiom).
Per the spec, empty values, zero, empty strings, and empty arrays are all
meaningful and must be preserved end-to-end — we pass them through unchanged.

### Attributes module

`Otel.API.Attributes` is likewise a pure type-alias module. An attribute is a
strict subset of `AnyValue`: scalars and homogeneous scalar arrays only. No
maps, no heterogeneous arrays, no nested recursion.

```elixir
@type key :: String.t()
@type scalar ::
        String.t() | {:bytes, binary()} | boolean() | integer() | float() | nil
@type value :: scalar() | [scalar()]
@type t :: %{key() => value()}
```

Module name is plural (`Attributes`) to match the spec's "Attribute
Collection" terminology and the `otel_attributes` precedent in
opentelemetry-erlang. `t/0` denotes the collection (the primary exported
type per Elixir convention); the scalar `key`/`scalar`/`value` aliases sit
alongside. We intentionally do not define a pair alias — with the
list-of-pairs collection form rejected (see below) and no call site
needing one, an extra alias would be dead weight.

#### Keys are strings only

We chose `String.t()` as the sole key type and explicitly rejected atoms.
This is stricter than `opentelemetry-erlang`, which accepts either atoms or
binaries. Rationale:

- **Spec fidelity.** The spec defines keys as non-empty strings. Accepting
  atoms requires an implicit runtime conversion.
- **Semantic-convention alignment.** An atom such as `:http_method` does
  *not* match the dotted semantic-convention name `"http.method"` after
  `Atom.to_string/1` — they would silently be treated as distinct keys,
  breaking convention matching.
- **Production readiness.** Our direction favours explicit over implicit.
  Avoiding a second runtime conversion heuristic (alongside the UTF-8 one)
  keeps the API surface predictable.
- **Escape hatch.** Callers who prefer atom ergonomics can call
  `Atom.to_string/1` themselves.

#### Value shape

`t:value/0` is `scalar() | [scalar()]` — a primitive or a homogeneous scalar
array, matching `opentelemetry-erlang`'s attribute type. The spec mandates
homogeneous arrays "MUST NOT contain values of different types", but our
typespec cannot cleanly express this: `[scalar()]` permits `[1, "a", true]`
as far as Dialyzer is concerned, and the obvious alternative (a union of
single-type arrays) clutters the typespec while leaving `[]` ambiguous.
Homogeneity is documented as a caller obligation in the moduledoc; runtime
enforcement can be added in the Finalization phase if needed. Per the spec
(L63–73), `null` entries within arrays are preserved as-is, so we permit
`nil` inside `[scalar()]`.

### Attribute Collections

A collection of attributes is a map only:

```elixir
@type t :: %{key() => value()}
```

We explicitly reject keyword lists (`[{key, value}]`) as an input shape. The
spec requires implementations to "MUST by default enforce that the exported
attribute collections contain only unique keys"
([common/README.md L215](../../references/opentelemetry-specification/specification/common/README.md#L215)).
A map guarantees uniqueness by construction, satisfying this rule without
a runtime validation pass. Accepting keyword lists would force us to choose
between a runtime uniqueness check and a silent spec violation; rejecting
them removes the dilemma.

A consequence is that existing call sites that accepted
`map() | [{String.t(), term()}]` (notably `Otel.API.Trace.Span.set_attributes/2`)
narrow to map only. This is an API-breaking change, acceptable pre-1.0.

Deeper collection-level concerns — cardinality control, duplicate-key policy
when *merging* two collections, overwrite-vs-append semantics on
`SetAttribute` — remain SDK responsibilities and are covered by the
respective SDK-layer Decisions (span creation, log record processing, etc.).

### Attribute Limits

The spec explicitly assigns attribute limits to the SDK:

> An SDK MAY implement model-specific limits, for example
> `SpanAttributeCountLimit` or `LogRecordAttributeCountLimit`.
>
> — [common/README.md L292–293](../../references/opentelemetry-specification/specification/common/README.md#L292)

The API layer defines only the types; it does not enforce count limits,
value-length limits, or truncation. Runtime enforcement lives in the SDK
and is covered by the existing [span-limits.md](span-limits.md) and
[logrecord-limits.md](logrecord-limits.md) Decisions.

### Modules

- `Otel.API.AnyValue` — type alias for the spec's `AnyValue` tagged union
  (primitive, heterogeneous array, string-keyed map, empty); documents the
  UTF-8 serialisation heuristic for the `string`/`byte array` split.
- `Otel.API.Attributes` — type aliases for attribute `key`, `scalar`,
  `value`, and `t` (the map-only collection).

## Compliance

- [Common](../compliance.md)
  * AnyValue — L45, L56, L60, L64, L67
  * map&lt;string, AnyValue&gt; — L80, L85, L93
  * Attribute — L183, L185, L187
  * Attribute Collections — L215, L223, L241
  * Attribute Limits — deferred to SDK; see
    [span-limits.md](span-limits.md) and
    [logrecord-limits.md](logrecord-limits.md)
