defmodule Otel.API.Common.Types do
  @moduledoc """
  **Local helper** (not in spec) — macro module injecting
  shared OTel type aliases into consumer modules.

  Consumer modules `use Otel.API.Common.Types` to gain three
  type aliases that describe every value our public and SDK
  APIs pass around:

  - `t:primitive/0` — single primitive value (OTel
    `common/README.md` §AnyValue L41-L50).
  - `t:primitive_any/0` — recursive extension, matching
    OTLP `AnyValue` (`common.proto` L25-L53).
  - `t:timestamp/0` — Unix epoch **nanoseconds** (uint64),
    the unit used by every OTel event/record/span timestamp
    and by every OTLP `time_unix_nano` field.

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

  ## Timestamp — nanoseconds across the whole spec

  OpenTelemetry uses **nanoseconds since the Unix epoch** as
  the single wire unit for every event/record/span timestamp
  across Trace, Logs, and Metrics. `t:timestamp/0` is
  narrowed to `0..2^64 - 1` to match OTLP's `fixed64`
  representation; always non-negative (timestamps count
  forward from 1970-01-01T00:00:00Z).

  **Only event-time.** The interval / timeout knobs
  `scheduledDelayMillis` (`logs/sdk.md` L542) and
  `exportIntervalMillis` (`metrics/sdk.md` L1450-L1453) are
  in **milliseconds** with their own scope; do not use
  `t:timestamp/0` for those — use a plain `integer()` and
  state the unit at the callsite.

  The type bounds the range but does not guard against unit
  mistakes: seconds (~1.7e9) and milliseconds (~1.7e12) both
  fit in the uint64 window, so callers are responsible for
  supplying nanoseconds.

  ## References

  - OTel Common §AnyValue: `opentelemetry-specification/specification/common/README.md` L39-L62
  - OTLP `AnyValue` proto: `opentelemetry-proto/opentelemetry/proto/common/v1/common.proto` L25-L53
  - OTel Trace API §Timestamp: `opentelemetry-specification/specification/trace/api.md` L71-L87
  - OTel Logs §Timestamp / §ObservedTimestamp: `opentelemetry-specification/specification/logs/data-model.md` L180-L204
  - OTel Metrics §Time: `opentelemetry-specification/specification/metrics/data-model.md` L417, L454
  """

  @doc """
  Injects the OTel type aliases into the consumer module.

  Adds three `@type` definitions to the caller:

  - `t:primitive/0` — single primitive value
    (string / bytes / boolean / integer / float / nil)
  - `t:primitive_any/0` — recursive `primitive` + list + map,
    matching OTLP `AnyValue`
  - `t:timestamp/0` — Unix epoch nanoseconds (uint64),
    bounded `0..2^64 - 1`

  ## Example

      defmodule MyModule do
        use Otel.API.Common.Types

        @type attributes :: %{String.t() => primitive() | [primitive()]}
        @type event :: %{name: String.t(), time: timestamp()}
      end
  """
  defmacro __using__(_opts) do
    quote do
      @type primitive ::
              String.t() | {:bytes, binary()} | boolean() | integer() | float() | nil

      @type primitive_any ::
              primitive() | [primitive_any()] | %{String.t() => primitive_any()}

      @type timestamp :: 0..0xFFFFFFFF_FFFFFFFF
    end
  end
end
