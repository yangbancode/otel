defmodule Otel.API.AnyValue do
  @moduledoc """
  Represents any value in the OpenTelemetry data model.

  `AnyValue` is a tagged union used where the data model accepts arbitrary
  values — most notably as a `LogRecord.Body`, or as a nested value inside
  `map<string, AnyValue>`. It is strictly broader than `Otel.API.Attributes.value/0`
  (which disallows maps, heterogeneous arrays, and nesting).

  ## Elixir representation

  The spec's primitive types map as follows:

  | Spec                              | Elixir                    |
  |-----------------------------------|---------------------------|
  | string                            | `t:String.t/0`            |
  | byte array                        | `{:bytes, t:binary/0}`    |
  | boolean                           | `t:boolean/0`             |
  | signed 64-bit integer             | `t:integer/0`             |
  | IEEE 754 double                   | `t:float/0`               |
  | array of AnyValue (heterogeneous) | `[t()]`                   |
  | `map<string, AnyValue>`           | `%{String.t() => t()}`    |
  | empty                             | `nil`                     |

  ## string vs byte array — explicit tagging

  The OpenTelemetry protocol (OTLP) distinguishes `string_value` from
  `bytes_value` in its `AnyValue` wire format. Elixir represents both as
  `t:binary/0`, so the two cannot be distinguished at the type level.

  This module uses an **explicit tag** to disambiguate:

  - A plain `t:binary/0` is always treated as a UTF-8 string and serialized
    as `string_value`. This is the common case (log messages, JSON-ish
    structured payloads, any human-readable text).
  - Raw byte payloads must be wrapped as `{:bytes, binary()}`. Exporters
    recognize the `:bytes` tag and emit the payload as `bytes_value`.

  Examples:

      # String body — plain binary
      %{body: "request started"}

      # Byte body — explicit tag
      %{body: {:bytes, <<0, 1, 2, 3>>}}

      # Mixed nested structure
      %{body: %{
        "event" => "upload",
        "content" => {:bytes, raw_payload},
        "size" => 1024
      }}

  A plain binary that was logically raw bytes but happens to be valid UTF-8
  will be serialized as `string_value` unless wrapped. Callers that need
  byte semantics must wrap explicitly.

  ### Invalid UTF-8 must be tagged

  The OTLP protobuf serializer enforces UTF-8 validity on `string_value`
  fields. A binary that is not valid UTF-8 and is **not** wrapped in
  `{:bytes, _}` will raise `Protobuf.EncodeError` at export time, not
  silently truncate. Callers that might emit non-UTF-8 payloads (raw
  protobuf bytes, compressed data, non-UTF-8 text) MUST wrap.

  ## Integer range

  Per the spec, integer values must fit in a signed 64-bit range (`-2^63`
  through `2^63 - 1`). Elixir's `t:integer/0` is arbitrary precision; the type
  alias here does not encode the 64-bit limit. Exporters are responsible for
  handling out-of-range values (typically by truncating or rejecting).

  ## Nesting

  Arbitrary deep nesting of arrays and maps is permitted. `AnyValue` is
  recursive through the `[t()]` and `%{String.t() => t()}` branches.
  """

  @typedoc """
  An `AnyValue` per the OpenTelemetry data model.

  See the moduledoc for the mapping from spec primitives to Elixir types,
  including the explicit `{:bytes, binary()}` tag used to request
  `bytes_value` encoding over OTLP.
  """
  @type t ::
          String.t()
          | {:bytes, binary()}
          | boolean()
          | integer()
          | float()
          | [t()]
          | %{String.t() => t()}
          | nil
end
