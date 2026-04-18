defmodule Otel.API.Attribute do
  @moduledoc """
  Types for an attribute key, an attribute value, and a collection of attributes.

  An attribute is a key-value pair whose value is a strict subset of
  `Otel.API.AnyValue.t/0`: scalars and homogeneous scalar arrays only. Maps,
  heterogeneous arrays, byte-array elements inside arrays, and nested
  recursion are **not** permitted in attribute values.

  ## Keys

  Keys are `t:String.t/0` only. Atoms are **not** accepted.

  This choice diverges from `opentelemetry-erlang`, which accepts either
  atoms or binaries. Rationale:

  - The OTel spec defines keys as strings; accepting atoms requires a
    runtime conversion that does not compose cleanly with semantic
    conventions (e.g., an atom `:http_method` does not match the
    convention name `"http.method"` after `Atom.to_string/1`).
  - Callers who prefer atom ergonomics may convert explicitly with
    `Atom.to_string/1`.

  ## Value type

  The `t:value/0` type covers:

  - `t:scalar/0` — `t:String.t/0`, `t:binary/0`, `t:boolean/0`,
    `t:integer/0`, `t:float/0`, or `nil`
  - `[scalar()]` — a homogeneous array of scalars

  Homogeneity ("a homogeneous array MUST NOT contain values of different
  types") is a spec-level constraint that this typespec does **not** enforce.
  `Dialyzer` sees `[scalar()]` as permitting mixed-type lists; runtime
  checking is deferred. Callers are responsible for ensuring homogeneity.

  `nil` within an array is permitted as-is per the spec (see
  `common/README.md` L63-73).

  ## Attribute collections

  Collections are represented as maps only:

      %{key() => value()}

  Keyword lists (`[{key, value}]`) are not accepted. A map guarantees unique
  keys by construction, which satisfies the spec's "MUST enforce unique keys"
  rule without a runtime validation pass.
  """

  @typedoc "Attribute key — a non-empty string."
  @type key :: String.t()

  @typedoc """
  A primitive attribute value.

  Byte arrays are permitted here via `t:binary/0`; the `string` vs
  `byte array` serialization split is handled by exporters (see
  `Otel.API.AnyValue` moduledoc).
  """
  @type scalar ::
          String.t() | binary() | boolean() | integer() | float() | nil

  @typedoc """
  An attribute value — a `t:scalar/0` or a homogeneous array of `t:scalar/0`.

  Homogeneity is a spec constraint not enforced at the type level.
  """
  @type value :: scalar() | [scalar()]

  @typedoc """
  A collection of attributes.

  Always a map. Keyword lists are not accepted — the map representation
  guarantees unique keys, satisfying the spec without runtime validation.
  """
  @type attributes :: %{key() => value()}
end
