defmodule Otel.API.Attribute do
  @moduledoc """
  Types for attribute keys, attribute values, and attribute collections.

  An attribute is a key-value pair whose value is a strict subset of
  `Otel.API.AnyValue.t/0`: primitives and homogeneous primitive arrays
  only. Maps, heterogeneous arrays, and nested recursion are **not**
  permitted in attribute values.

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

  - `t:primitive/0` — `t:String.t/0`, `{:bytes, t:binary/0}`, `t:boolean/0`,
    `t:integer/0`, `t:float/0`, or `nil`
  - `t:value/0` — `primitive()` or `[primitive()]` (homogeneous array)

  The spec term is "primitive" (see `common/README.md` L235 — "Attribute
  values can be primitive types (int, string, float, bool) …").

  Plain binaries are treated as UTF-8 strings; raw byte payloads must use
  the explicit `{:bytes, t:binary/0}` tag (same convention as
  `Otel.API.AnyValue`). Exporters encode `{:bytes, _}` as OTLP
  `bytes_value` and everything else as the corresponding primitive
  variant.

  Homogeneity ("a homogeneous array MUST NOT contain values of different
  types") is a spec-level constraint that this typespec does **not** enforce.
  `Dialyzer` sees `[primitive()]` as permitting mixed-type lists; runtime
  checking is deferred. Callers are responsible for ensuring homogeneity.

  `nil` within an array is permitted as-is per the spec (see
  `common/README.md` L63-73).

  ## Collection

  There is no dedicated `attributes` type alias. Consumers spell out the
  map shape at use sites:

      attributes: %{Otel.API.Attribute.key() => Otel.API.Attribute.value()}

  Keyword lists (`[{key, value}]`) are not accepted. A map guarantees
  unique keys by construction, which satisfies the spec's "MUST enforce
  unique keys" rule without a runtime validation pass.

  Count and value-length limits are applied at the container level —
  see `Otel.SDK.Trace.Span.apply_attribute_limits/3` — because OTLP
  exposes `dropped_attributes_count` per container (Span, Event, Link,
  LogRecord), not per attribute collection. Keeping attributes as a
  pure map avoids leaking container policy into the data type.
  """

  @typedoc "Attribute key — a non-empty string."
  @type key :: String.t()

  @typedoc """
  A primitive attribute value.

  Plain binaries encode as OTLP `string_value`. Use `{:bytes, binary()}`
  to request `bytes_value` encoding for raw byte payloads (see
  `Otel.API.AnyValue` moduledoc for the rationale).
  """
  @type primitive ::
          String.t() | {:bytes, binary()} | boolean() | integer() | float() | nil

  @typedoc """
  An attribute value — a `t:primitive/0` or a homogeneous array of
  `t:primitive/0`.

  Homogeneity is a spec constraint not enforced at the type level.
  """
  @type value :: primitive() | [primitive()]
end
