defmodule Otel.API.Trace.SpanId do
  @moduledoc """
  Opaque 64-bit Span identifier (W3C `parent-id` / OTel
  `trace/api.md` §SpanContext SpanId, L234-L235).

  The OTel spec defines a valid `SpanId` as an 8-byte array with
  at least one non-zero byte (L234-L235). On the wire, W3C Trace
  Context encodes it as a 16-character lowercase hex string
  (`parent-id = 16HEXDIGLC`, §parent-id). Internally we store it
  as a non-negative 64-bit integer and expose it through
  `@opaque` so Dialyzer distinguishes it from unrelated integers
  — and from `Otel.API.Trace.TraceId`.

  Per spec L266 *"The API SHOULD NOT expose details about how
  they are internally stored"* — callers go through `to_hex/1`
  / `to_bytes/1` rather than the raw integer.

  ## Public API

  | Function | Role |
  |---|---|
  | `new/1` | **Local helper** — construct from a validated integer |
  | `valid?/1` | **OTel API MUST** (non-zero byte check, L234-L235) |
  | `to_hex/1` | **OTel API MUST** (Hex retrieval, L258-L262) |
  | `to_bytes/1` | **OTel API MUST** (Binary retrieval, L263-L264) |
  | `is_invalid/1` (guard) | **Local helper** — guard-safe all-zero check |

  ## References

  - OTel Trace API §SpanContext SpanId: `opentelemetry-specification/specification/trace/api.md` L234-L235, L256-L266
  - W3C Trace Context Level 2 §parent-id: `w3c-trace-context/spec/20-http_request_header_format.md` §parent-id
  """

  @max_value 0xFFFFFFFF_FFFFFFFF
  @hex_length 16

  @typedoc """
  A 64-bit Span identifier (W3C `parent-id`).

  Stored as a `0..2^64 - 1` integer but declared `@opaque` so
  callers cannot construct one with an arbitrary integer literal
  from outside the module. Use `new/1` at construction
  boundaries (e.g. random generation in the SDK id generator)
  and `to_hex/1` / `to_bytes/1` for serialisation.

  The all-zero value is reserved as the invalid sentinel meaning
  "no span"; `valid?/1` returns `false` for it (spec L234-L235 +
  W3C §parent-id L113-L117).
  """
  @opaque t :: 0..0xFFFFFFFF_FFFFFFFF

  @doc """
  **Local helper** — wrap a 64-bit unsigned integer as a `t()`.

  The opaque-boundary-respecting way to turn a raw integer (e.g.
  from an ID generator) into a `SpanId.t()`. The `@spec` input
  range is the type gate — Dialyzer flags literal out-of-range
  callers; runtime-origin values are the caller's
  responsibility.
  """
  @spec new(integer :: 0..0xFFFFFFFF_FFFFFFFF) :: t()
  def new(integer) do
    integer
  end

  @doc """
  Guard-safe check for the all-zero invalid sentinel.

  Use inside a pattern-match guard instead of comparing against
  `0` directly (which would break opacity outside this module).
  """
  defguard is_invalid(span_id) when span_id === 0

  @doc """
  **OTel API MUST** — "IsValid for SpanId" (`trace/api.md`
  L234-L235, L268-L271).

  Returns `true` iff the SpanId has at least one non-zero byte.
  Per spec the all-zero value (`0000000000000000`) is explicitly
  invalid (W3C §parent-id L113-L117).
  """
  @spec valid?(span_id :: t()) :: boolean()
  def valid?(0), do: false

  def valid?(span_id)
      when is_integer(span_id) and span_id > 0 and span_id <= @max_value,
      do: true

  @doc """
  **OTel API MUST** — "Hex Retrieval" (`trace/api.md` L258-L262).

  Returns the SpanId as a **16-character lowercase** hex string
  (zero-padded). Matches the W3C `parent-id` wire format
  (§parent-id: `16HEXDIGLC`).
  """
  @spec to_hex(span_id :: t()) :: <<_::128>>
  def to_hex(span_id) do
    span_id
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(@hex_length, "0")
  end

  @doc """
  **OTel API MUST** — "Binary Retrieval" (`trace/api.md`
  L263-L264).

  Returns the SpanId as an 8-byte big-endian binary.
  """
  @spec to_bytes(span_id :: t()) :: <<_::64>>
  def to_bytes(span_id) do
    <<span_id::unsigned-integer-size(64)>>
  end
end
