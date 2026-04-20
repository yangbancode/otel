defmodule Otel.API.Attribute do
  @moduledoc """
  Types for a single attribute — `key`, `scalar`, `value`.

  An attribute is a key-value pair. This module defines the types for the
  single-attribute view (one key, one value). For the **collection** view
  (map of many attributes), see `Otel.API.Attributes`.

  Attribute values are a strict subset of `Otel.API.AnyValue.t/0`: scalars
  and homogeneous scalar arrays only. Maps, heterogeneous arrays, and
  nested recursion are **not** permitted.

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

  - `t:scalar/0` — `t:String.t/0`, `{:bytes, t:binary/0}`, `t:boolean/0`,
    `t:integer/0`, `t:float/0`, or `nil`
  - `t:value/0` — `scalar()` or `[scalar()]` (homogeneous array)

  Plain binaries are treated as UTF-8 strings; raw byte payloads must use
  the explicit `{:bytes, t:binary/0}` tag (same convention as
  `Otel.API.AnyValue`). Exporters encode `{:bytes, _}` as OTLP
  `bytes_value` and everything else as the corresponding scalar variant.

  Homogeneity ("a homogeneous array MUST NOT contain values of different
  types") is a spec-level constraint that this typespec does **not** enforce.
  `Dialyzer` sees `[scalar()]` as permitting mixed-type lists; runtime
  checking is deferred. Callers are responsible for ensuring homogeneity.

  `nil` within an array is permitted as-is per the spec (see
  `common/README.md` L63-73).
  """

  @typedoc "Attribute key — a non-empty string."
  @type key :: String.t()

  @typedoc """
  A primitive attribute value.

  Plain binaries encode as OTLP `string_value`. Use `{:bytes, binary()}`
  to request `bytes_value` encoding for raw byte payloads (see
  `Otel.API.AnyValue` moduledoc for the rationale).
  """
  @type scalar ::
          String.t() | {:bytes, binary()} | boolean() | integer() | float() | nil

  @typedoc """
  An attribute value — a `t:scalar/0` or a homogeneous array of `t:scalar/0`.

  Homogeneity is a spec constraint not enforced at the type level.
  """
  @type value :: scalar() | [scalar()]
end
