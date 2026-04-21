defmodule Otel.API.Trace.TraceId do
  @moduledoc """
  Opaque 128-bit Trace identifier (W3C `trace-id` / OTel
  `trace/api.md` §SpanContext TraceId, L231-L232).

  The OTel spec defines a valid `TraceId` as a 16-byte array
  with at least one non-zero byte (L231-L232). On the wire,
  W3C Trace Context encodes it as a 32-character lowercase hex
  string (`trace-id = 32HEXDIGLC`, §trace-id). Internally we
  store it as a non-negative 128-bit integer and expose it
  through `@opaque` so Dialyzer distinguishes it from
  unrelated integers — and from `Otel.API.Trace.SpanId`.

  Per spec L266 *"The API SHOULD NOT expose details about how
  they are internally stored"* — callers go through `to_hex/1`
  / `to_bytes/1` rather than the raw integer. The
  `to_integer/1` escape hatch exists specifically for SDK
  samplers that perform bit arithmetic on the id (see
  `Otel.SDK.Trace.Sampler.TraceIdRatioBased`).

  ## Public API

  | Function | Role |
  |---|---|
  | `new/1` | **Local helper** — construct from a validated integer |
  | `valid?/1` | **OTel API MUST** (non-zero byte check, L231-L232) |
  | `to_hex/1` | **OTel API MUST** (Hex retrieval, L258-L262) |
  | `to_bytes/1` | **OTel API MUST** (Binary retrieval, L263-L264) |
  | `to_integer/1` | **Local helper** — SDK bit-arithmetic escape hatch |

  ## References

  - OTel Trace API §SpanContext TraceId: `opentelemetry-specification/specification/trace/api.md` L231-L232, L256-L266
  - W3C Trace Context Level 2 §trace-id: `w3c-trace-context/spec/20-http_request_header_format.md` §trace-id
  """

  @max_value 0xFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF
  @hex_length 32

  @typedoc """
  A 128-bit Trace identifier (W3C `trace-id`).

  Stored as a `0..2^128 - 1` integer but declared `@opaque` so
  callers cannot construct one with an arbitrary integer literal
  from outside the module. Use `new/1` at construction
  boundaries (e.g. random generation in the SDK id generator)
  and `to_hex/1` / `to_bytes/1` for serialisation.

  The all-zero value is reserved as the invalid sentinel meaning
  "no trace"; `valid?/1` returns `false` for it (spec L231-L232 +
  W3C §trace-id L103).
  """
  @opaque t :: 0..0xFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF

  @doc """
  **Local helper** — wrap a 128-bit unsigned integer as a `t()`.

  The opaque-boundary-respecting way to turn a raw integer (e.g.
  from an ID generator) into a `TraceId.t()`. The `@spec` input
  range is the type gate — Dialyzer flags literal out-of-range
  callers; runtime-origin values are the caller's
  responsibility.
  """
  @spec new(integer :: 0..0xFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF) :: t()
  def new(integer) do
    integer
  end

  @doc """
  **OTel API MUST** — "IsValid for TraceId" (`trace/api.md`
  L231-L232, L268-L271).

  Returns `true` iff the TraceId has at least one non-zero byte.
  Per spec the all-zero value
  (`00000000000000000000000000000000`) is explicitly invalid
  (W3C §trace-id L103).

  Accepts any term as a robust predicate — returns `false` for
  `0`, negatives, out-of-range integers, and non-integers.
  """
  @spec valid?(trace_id :: term()) :: boolean()
  def valid?(trace_id)
      when is_integer(trace_id) and trace_id > 0 and trace_id <= @max_value,
      do: true

  def valid?(_), do: false

  @doc """
  **OTel API MUST** — "Hex Retrieval" (`trace/api.md` L258-L262).

  Returns the TraceId as a **32-character lowercase** hex string
  (zero-padded). Matches the W3C `trace-id` wire format
  (§trace-id: `32HEXDIGLC`).
  """
  @spec to_hex(trace_id :: t()) :: <<_::256>>
  def to_hex(trace_id) do
    trace_id
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(@hex_length, "0")
  end

  @doc """
  **OTel API MUST** — "Binary Retrieval" (`trace/api.md`
  L263-L264).

  Returns the TraceId as a 16-byte big-endian binary.
  """
  @spec to_bytes(trace_id :: t()) :: <<_::128>>
  def to_bytes(trace_id) do
    <<trace_id::unsigned-integer-size(128)>>
  end

  @doc """
  **Local helper** — underlying non-negative integer escape hatch.

  Exposed so SDK components can perform bit arithmetic on the
  TraceId (e.g. `TraceIdRatioBased` takes the lower 64 bits as a
  probability hash). Callers outside the SDK should prefer
  `to_hex/1` or `to_bytes/1`.
  """
  @spec to_integer(trace_id :: t()) :: non_neg_integer()
  def to_integer(trace_id), do: trace_id
end
