defmodule Otel.API.AnyValue do
  @moduledoc """
  Represents any value in the OpenTelemetry data model.

  `AnyValue` is a tagged union used where the data model accepts arbitrary
  values — most notably as a `LogRecord.Body`, or as a nested value inside
  `map<string, AnyValue>`. It is strictly broader than `Otel.API.Attribute.value/0`
  (which disallows maps, heterogeneous arrays, and nesting).

  ## Elixir representation

  The spec's primitive types map as follows:

  | Spec                              | Elixir                    |
  |-----------------------------------|---------------------------|
  | string                            | `t:String.t/0`            |
  | byte array                        | `t:binary/0`              |
  | boolean                           | `t:boolean/0`             |
  | signed 64-bit integer             | `t:integer/0`             |
  | IEEE 754 double                   | `t:float/0`               |
  | array of AnyValue (heterogeneous) | `[t()]`                   |
  | `map<string, AnyValue>`           | `%{String.t() => t()}`    |
  | empty                             | `nil`                     |

  ## string vs byte array

  The OpenTelemetry protocol (OTLP) distinguishes `string_value` from
  `bytes_value` in its `AnyValue` wire format. Elixir represents both as
  `t:binary/0`, so the distinction cannot be expressed at the type level.
  Exporters resolve the ambiguity at serialization time by checking UTF-8
  validity: a valid UTF-8 binary is emitted as `string_value`, an invalid one
  as `bytes_value`.

  A binary that is accidentally valid UTF-8 but was intended as raw bytes will
  therefore be serialized as a string. Callers who need to force byte
  semantics on a UTF-8-valid payload must rely on exporter-specific
  configuration.

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
  including the `string` vs `byte array` disambiguation rule.
  """
  @type t ::
          String.t()
          | binary()
          | boolean()
          | integer()
          | float()
          | [t()]
          | %{String.t() => t()}
          | nil
end
