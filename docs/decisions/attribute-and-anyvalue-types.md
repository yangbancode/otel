# Attribute and AnyValue Types

## Question

How do we represent attribute values and `AnyValue` in the Elixir
typespec, and where do those types live?

## Decision

A single module, `Otel.API.Common.Types`, exposes two type aliases via a
`__using__/1` macro. Modules that carry OTel values pull them in with
`use Otel.API.Common.Types`:

```elixir
defmodule Otel.API.Common.Types do
  defmacro __using__(_opts) do
    quote do
      @type primitive ::
              String.t() | {:bytes, binary()} | boolean() | integer() | float() | nil

      @type primitive_any ::
              primitive() | [primitive_any()] | %{String.t() => primitive_any()}
    end
  end
end
```

The `Otel.API.Attribute` and `Otel.API.AnyValue` modules that existed
earlier are removed. `primitive/0` covers the attribute-value scalar,
and `primitive_any/0` covers the spec's recursive `AnyValue` — the two
concepts the rest of the API layer actually needs.

### `primitive/0`

A single primitive value: string, raw bytes (tagged), boolean, integer,
float, or nil. Matches the spec's "primitive types (int, string, float,
bool)" (`common/README.md` L235) plus `nil` per the spec's empty-value
allowance and `{:bytes, binary()}` to disambiguate string-vs-bytes.

### `primitive_any/0`

The recursive `AnyValue` variant from the OTel data model: a primitive,
a list of `primitive_any`, or a `String.t()`-keyed map of
`primitive_any`. Used for `LogRecord.body` and anywhere the full
spec-level AnyValue expressiveness is required (nested maps,
heterogeneous arrays).

Elixir/Erlang typespecs require recursion to be expressed through a
named `@type`, so this alias cannot be inlined at call sites.

### Why the macro (`use Otel.API.Common.Types`)

Elixir's `import` does not import types — types are always
module-scoped. To keep the two aliases defined in one place yet
available under short, local names in every consumer, we use a
`defmacro __using__/1` that injects both `@type` statements into the
caller module.

The result is that a module like `Otel.API.Trace.Span` can write:

```elixir
use Otel.API.Common.Types

@spec set_attribute(..., value :: primitive() | [primitive()]) :: :ok
```

rather than repeating `Otel.API.Common.Types.primitive() |
[Otel.API.Common.Types.primitive()]` at every call site. The types are
structurally identical across modules (same definition), so Dialyzer
unifies them without issue.

This is the same "extend me with a vocabulary" idiom Phoenix uses with
`use Phoenix.Controller` and Ecto uses with `use Ecto.Schema` — the
`use` verb declares "this module speaks OTel types".

### Why `primitive_any` (and not `any_value`)

We considered `any_value`, `any`, `anything`, and `otel_any`. Landed on
`primitive_any`:

- `any` is a reserved built-in type in Elixir — `@type any :: ...`
  fails to compile.
- `any_value` places a `_value` suffix on a type name, which feels
  redundant (a type already *is* a value shape).
- `primitive_any` gives both types a shared `primitive_` root, making
  the family relationship visible: `primitive` is the base scalar,
  `primitive_any` is its recursive extension. The name also hints that
  the recursion is built *out of* primitives.
- Swapping to `any_primitive` would read more naturally in English but
  misleads — the type also admits lists and maps, not just single
  primitives.

### Attribute collections are inline

Per the spec, attribute values are **not** the full `primitive_any`.
They are restricted to primitives and homogeneous arrays of primitives
(no maps, no heterogeneous arrays, no nesting). No separate alias
exists for this narrower type. Struct fields spell the map shape
directly:

```elixir
defmodule Otel.API.InstrumentationScope do
  use Otel.API.Common.Types

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          schema_url: String.t(),
          attributes: %{String.t() => primitive() | [primitive()]}
        }
end
```

Writing the map inline keeps the reader close to the actual shape —
no indirection to chase — at the cost of a slightly longer field
annotation. With ~15 use sites all writing the identical shape and
`primitive/0` as the single source of truth for the primitive-scalar
type, there is no practical drift risk.

### string vs bytes

Elixir collapses UTF-8 strings and raw byte arrays into a single
`t:binary/0`. OTLP's `AnyValue` proto exposes them as `string_value` and
`bytes_value` oneof variants. We disambiguate with an explicit tag —
plain `String.t()` / `binary()` encodes as `string_value`, while
`{:bytes, binary()}` encodes as `bytes_value`. The exporter pattern-
matches the `:bytes` tag.

Invalid UTF-8 binaries passed without the tag surface as
`Protobuf.EncodeError` at export time — the protobuf library refuses to
encode non-UTF-8 bytes into a `string_value` field. The moduledoc of
`Otel.API.Common.Types` documents this contract.

### Integer range

Per the spec, integer values must fit in a signed 64-bit range (`-2^63`
through `2^63 - 1`). Elixir's `t:integer/0` is arbitrary precision; the
`primitive` alias does not encode the 64-bit limit. Exporters are
responsible for out-of-range handling.

### Attribute homogeneity

The spec mandates homogeneous arrays "MUST NOT contain values of
different types". Our typespec cannot cleanly express this:
`[primitive()]` permits `[1, "a", true]` as far as Dialyzer is
concerned. Homogeneity is a caller obligation documented in the
moduledoc; runtime enforcement can be added in the Finalization phase
if needed. Per the spec (L63–73), `null` entries within arrays are
preserved as-is, so `nil` is permitted inside `[primitive()]`.

### Attribute keys are plain `String.t()`

Attribute keys are typed as `String.t()` directly at call sites. We
deliberately do not expose an `Otel.API.Common.Types.key/0` alias —
`Otel.API.Attribute.key/0` previously aliased `String.t()` with no
additional constraint, which is pure indirection.

This choice diverges from `opentelemetry-erlang`, which accepts either
atoms or binaries as keys. Rationale:

- The OTel spec defines keys as non-empty strings.
- Accepting atoms requires an implicit runtime conversion that does
  not compose cleanly with semantic conventions (e.g., atom
  `:http_method` does not match the convention `"http.method"` after
  `Atom.to_string/1`).
- Callers who prefer atom ergonomics convert explicitly with
  `Atom.to_string/1`.

### Why not opaque types or validation helpers?

Opaque types (`@opaque` plus constructor functions) would force every
caller to wrap every attribute value or log body value. None of the
other OTel SDKs (Java, Python, Go, erlang) take that approach — it
trades ergonomics for a form of safety that is better covered by
runtime validation on specific narrow constraints (e.g. UTF-8 validity,
int64 range).

Runtime validation helpers could live alongside the type aliases in
`Otel.API.Common.Types` if a future requirement drives them (e.g.
`valid_int64?/1`, `valid_utf8?/1`). We have none today because the
current flow surfaces the relevant errors either via the protobuf
encoder (UTF-8) or via exporter handling.

### Attribute limits

The spec explicitly assigns attribute limits to the SDK:

> An SDK MAY implement model-specific limits, for example
> `SpanAttributeCountLimit` or `LogRecordAttributeCountLimit`.
>
> — [common/README.md L292–293](../../references/opentelemetry-specification/specification/common/README.md#L292)

The API layer defines only the types; it does not enforce count
limits, value-length limits, or truncation. Runtime enforcement lives
in the SDK and is covered by the existing [span-limits.md](span-limits.md)
and [logrecord-limits.md](logrecord-limits.md) Decisions.

### Modules

- `Otel.API.Common.Types` — exposes `primitive/0` and `primitive_any/0` via a
  `__using__/1` macro. Modules inject them with `use Otel.API.Common.Types`.
  Attribute keys are `String.t()` directly; attribute collections are
  spelled inline as `%{String.t() => primitive() | [primitive()]}`.

## Compliance

- [Common](../compliance.md)
  * AnyValue — L45, L56, L60, L64, L67
  * map&lt;string, AnyValue&gt; — L80, L85, L93
  * Attribute — L183, L185, L187
  * Attribute Collections — L215, L223, L241
