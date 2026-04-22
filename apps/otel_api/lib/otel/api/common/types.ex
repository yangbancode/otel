defmodule Otel.API.Common.Types do
  @moduledoc """
  **Local helper** (not in spec) — macro module injecting
  shared OTel type aliases into consumer modules.

  Consumer modules `use Otel.API.Common.Types` to gain two
  type aliases that describe every value our public and SDK
  APIs pass around:

  - `t:primitive/0` — a single primitive value (OTel
    `common/README.md` §AnyValue L41-L50).
  - `t:primitive_any/0` — the recursive extension of
    `primitive/0` into lists and maps, matching OTLP
    `AnyValue` (`common.proto` L25-L53).

  ## Where each is used

  Attribute values (Span, Event, Link, Metric, etc.) are
  `primitive` or a homogeneous list of `primitive`. Per spec
  L45-L46 attribute values MUST NOT mix types within one
  array and MUST NOT be maps, so attribute-carrying struct
  fields spell the type as:

      attributes: %{String.t() => primitive() | [primitive()]}

  The map type is written inline at each call site rather
  than behind an alias — attribute keys are `t:String.t/0`
  and attribute values are a narrow subset of `primitive_any`,
  so an extra alias would hide no useful information.

  `LogRecord.body` is `primitive_any/0` — the OTLP `AnyValue`
  oneof, which permits nested maps and heterogeneous arrays
  (`common.proto` L28-L42).

  ## string vs bytes

  Elixir collapses UTF-8 strings and raw byte arrays into a
  single `t:binary/0`. OTLP's `AnyValue` proto exposes them
  as separate `string_value` and `bytes_value` oneof variants
  (`common.proto` L32, L36). This module disambiguates with an
  explicit tag:

  - plain `String.t()` / `binary()` → `string_value`
  - `{:bytes, binary()}` → `bytes_value`

  The exporter pattern-matches the `:bytes` tag. Invalid UTF-8
  binaries passed without the tag surface as
  `Protobuf.EncodeError` at export time (the protobuf library
  refuses to encode non-UTF-8 bytes into a `string_value`
  field).

  ## Empty values (nil)

  `primitive/0` includes `nil` per `common/README.md`
  §AnyValue L50-L51 language-dependent clause:

  > *"an empty value if supported by the language, (e.g.
  > `null`, `undefined` in JavaScript/TypeScript, `None` in
  > Python, `nil` in Go/Ruby, not supported in Erlang, etc.)"*

  Elixir supports `nil` natively, and spec L63 confirms that
  *"null is a valid attribute value"* for the attribute-map
  contexts where `primitive/0` appears. `nil` is also
  preserved through `primitive_any/0` for `LogRecord.body`
  and through `[primitive()]` for array attribute values per
  spec L67-L68 MUST *"null values within arrays MUST be
  preserved as-is (i.e., passed on to processors / exporters
  as null)"*.

  This diverges from `opentelemetry-erlang`, which — per
  spec — does not support empty values (Erlang is explicitly
  listed as "not supported"). Our inclusion is spec-aligned
  via the language-dependent clause; Elixir's idiomatic
  nullable pattern makes `nil` the natural empty
  representation and matches what Elixir users already
  expect from any struct field typed as `String.t() | nil`.

  ## Attribute key constraints

  Spec `common/README.md` §Attribute L185 MUST:

  > *"The attribute key MUST be a non-`null` and non-empty
  > string."*

  The attribute-carrying maps across this project use
  `String.t()` as the key type:

      attributes: %{String.t() => primitive() | [primitive()]}

  Two aspects of the MUST:

  - **Non-null is enforced at compile time.** `String.t()`
    is an alias for `t:binary/0`, which does not include
    `nil` (nil is an atom, not a binary). Dialyzer rejects
    a literal `%{nil => value}` at the call site.

  - **Non-empty is not expressible in Elixir's type
    system.** Dialyzer has no "non-empty binary" primitive —
    `<<_::_*8>>` matches any byte count including zero. An
    empty-string key `%{"" => value}` passes the typespec
    unflagged.

  Runtime enforcement of the non-empty MUST is therefore an
  SDK concern — the API layer is a happy-path dispatcher
  (per `.claude/rules/code-conventions.md`
  §"Not error handling") and does not guard against empty
  keys. SDK implementations are expected to drop or
  otherwise handle empty-key attributes at storage /
  export time per spec L185.

  API users are responsible for not passing empty-string
  keys. Downstream behaviour on empty keys depends on the
  installed SDK and exporter.

  ## Integer range

  Per spec L44 integer values must fit in a signed 64-bit
  range (`-2^63` through `2^63 - 1`). Elixir's `t:integer/0`
  is arbitrary precision; this typespec does not encode the
  limit. Exporters are responsible for out-of-range handling.

  ## Array homogeneity

  Attribute values permit only **homogeneous** arrays — spec
  L45-L46 forbids mixed types inside one array.
  `[primitive()]` in a typespec permits `[1, "a", true]` as
  far as Dialyzer is concerned; runtime homogeneity is a
  caller obligation documented here but not checked.

  ## Performance

  Per `common/README.md` L56-L57 SHOULD:

  > *"APIs SHOULD be documented in a way to communicate to
  > users that using array and map values may carry higher
  > performance overhead compared to primitive values."*

  Single-primitive attribute values (`String.t()`,
  `integer()`, etc.) are the cheapest. `[primitive()]`
  arrays and `primitive_any()` map/list values
  (`LogRecord.body`) carry additional allocation and
  traversal cost at recording time, during SDK aggregation,
  and at exporter serialization. Prefer primitives where
  the signal permits.

  ## References

  - OTel Common §AnyValue: `opentelemetry-specification/specification/common/README.md` L39-L74
  - OTel Common §Attributes: `opentelemetry-specification/specification/common/README.md` L179-L187
  - OTLP `AnyValue` proto: `opentelemetry-proto/opentelemetry/proto/common/v1/common.proto` L25-L53
  """

  @doc """
  Injects the OTel type aliases into the consumer module.

  Adds two `@type` definitions to the caller:

  - `t:primitive/0` — single primitive value
    (string / bytes / boolean / integer / float / nil)
  - `t:primitive_any/0` — recursive `primitive` + list + map,
    matching OTLP `AnyValue`

  ## Example

      defmodule MyModule do
        use Otel.API.Common.Types

        @type attributes :: %{String.t() => primitive() | [primitive()]}
      end
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
