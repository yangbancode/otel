defmodule Otel.API.Types do
  @moduledoc """
  Shared types for the OpenTelemetry data model.

  Use `use Otel.API.Types` in modules that carry OTel values. The macro
  injects two type aliases that describe every value our public and SDK
  APIs pass around:

  - `t:primitive/0` — a single primitive value (spec "primitive types",
    `common/README.md` L235).
  - `t:primitive_any/0` — the recursive extension of `primitive/0` into
    lists and maps (OTLP `AnyValue`).

  ## Where each is used

  Attribute values (Span, Event, Link, Metric, etc.) are `primitive` or
  a homogeneous list of `primitive`. Per spec, attribute values MUST NOT
  be maps or heterogeneous arrays, so attribute-carrying struct fields
  spell the type as:

      attributes: %{String.t() => primitive() | [primitive()]}

  The map type is written inline at each call site rather than behind an
  alias — attribute keys are `t:String.t/0` and attribute values are a
  narrow subset of `primitive_any`, so an extra alias would hide no
  useful information.

  `LogRecord.body` is `primitive_any/0` — the spec's `AnyValue` oneof,
  permitting nested maps and heterogeneous arrays.

  ## string vs bytes

  Elixir collapses UTF-8 strings and raw byte arrays into a single
  `t:binary/0`. OTLP's `AnyValue` proto exposes them as `string_value`
  and `bytes_value` oneof variants. This module disambiguates with an
  explicit tag:

  - plain `String.t()` / `binary()` → `string_value`
  - `{:bytes, binary()}` → `bytes_value`

  The exporter pattern-matches the `:bytes` tag. Invalid UTF-8 binaries
  passed without the tag surface as `Protobuf.EncodeError` at export
  time (the protobuf library refuses to encode non-UTF-8 bytes into a
  `string_value` field).

  ## Integer range

  Per the spec, integer values must fit in a signed 64-bit range (`-2^63`
  through `2^63 - 1`). Elixir's `t:integer/0` is arbitrary precision;
  this typespec does not encode the limit. Exporters are responsible for
  out-of-range handling.

  ## Array homogeneity

  Attribute values permit only **homogeneous** arrays — spec forbids
  mixed types inside one array. `[primitive()]` in a typespec permits
  `[1, "a", true]` as far as Dialyzer is concerned; runtime homogeneity
  is a caller obligation documented here but not checked.
  """

  defmacro __using__(_opts) do
    quote do
      @type primitive ::
              String.t() | {:bytes, binary()} | boolean() | integer() | float() | nil

      @type primitive_any ::
              primitive() | [primitive_any()] | %{String.t() => primitive_any()}
    end
  end
end
