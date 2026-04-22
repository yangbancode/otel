defmodule Otel.API.Trace.SpanContext do
  @moduledoc """
  Immutable context of a Span (spec `trace/api.md` §SpanContext,
  Status: **Stable**, L221-L278).

  Carries the identifiers that must be serialized and propagated
  alongside any cross-process or cross-service call: a `TraceId`,
  a `SpanId`, a `TraceFlags` byte, a `TraceState`, and an
  `is_remote` bit. Representation conforms to the W3C Trace
  Context Level 2 specification (per spec L226-L229).

  Spec requirements met:

  - **MUST** creation API (L252-L254) → `new/2,3,4`
  - **MUST** hex retrieval for TraceId/SpanId (L256-L266) →
    `trace_id_hex/1`, `span_id_hex/1`
  - **MUST** binary retrieval (L256-L266) → `trace_id_bytes/1`,
    `span_id_bytes/1`
  - **MUST** IsValid (L268-L271) → `valid?/1`
  - **MUST** IsRemote (L273-L278) → `remote?/1`

  The TraceId / SpanId are stored as `Otel.API.Trace.TraceId.t()`
  and `Otel.API.Trace.SpanId.t()` so Dialyzer distinguishes them
  from unrelated integers (and from each other). Hex / binary
  accessors delegate to those modules — caller code should go
  through the accessors rather than the raw field per spec L266
  *"The API SHOULD NOT expose details about how they are
  internally stored"*.

  SDK-specific concerns (e.g. `is_recording`, SDK dispatch) are
  deliberately absent per `.claude/rules/code-conventions.md`
  §Layer independence — those fields belong to the SDK layer.

  ## Public API

  | Function | Role |
  |---|---|
  | `new/2,3,4` | **Application** (OTel API MUST) — Creation (L252-L254) |
  | `valid?/1` | **Application** (OTel API MUST) — IsValid (L268-L271) |
  | `remote?/1` | **Application** (OTel API MUST) — IsRemote (L273-L278) |
  | `trace_id_hex/1`, `span_id_hex/1`, `trace_id_bytes/1`, `span_id_bytes/1` | **Application** (OTel API MUST) — Retrieving (L256-L266) |

  ## References

  - OTel Trace API §SpanContext: `opentelemetry-specification/specification/trace/api.md` L221-L278
  - W3C Trace Context Level 2 §trace-flags: `w3c-trace-context/spec/20-http_request_header_format.md` §trace-flags
  """

  @typedoc """
  W3C `trace-flags` — an 8-bit unsigned integer carrying flags
  that apply to all traces (spec `trace/api.md` L237-L242).

  Per W3C Trace Context Level 2 §trace-flags the value occupies
  exactly 8 bits (range `0..255`). Two bits are currently
  defined:

  - bit 0 (`0b01`): **Sampled**.
  - bit 1 (`0b10`): **Random Trace ID Flag** (Level 2 addition).

  Callers check bits directly with `Bitwise.band/2`; other bits
  are reserved.
  """
  @type trace_flags :: 0..255

  @typedoc """
  A SpanContext struct (spec `trace/api.md` §SpanContext,
  L221-L250).

  Fields:

  - `trace_id` — 128-bit trace identifier (W3C `trace-id`).
    Valid when at least one byte is non-zero (spec L231-L232).
  - `span_id` — 64-bit span identifier (W3C `parent-id`). Valid
    when at least one byte is non-zero (spec L234-L235).
  - `trace_flags` — 8-bit flag byte (see `t:trace_flags/0`).
  - `tracestate` — vendor-specific key/value pairs (W3C
    `tracestate`, §3.3).
  - `is_remote` — `true` when the SpanContext was propagated
    from a remote parent (spec L273-L278). The extracting
    Propagator sets this; child spans produced locally have
    `is_remote: false`.
  """
  @type t :: %__MODULE__{
          trace_id: Otel.API.Trace.TraceId.t(),
          span_id: Otel.API.Trace.SpanId.t(),
          trace_flags: trace_flags(),
          tracestate: Otel.API.Trace.TraceState.t(),
          is_remote: boolean()
        }

  defstruct trace_id: 0,
            span_id: 0,
            trace_flags: 0,
            tracestate: Otel.API.Trace.TraceState.new(),
            is_remote: false

  @doc """
  **Application** (OTel API MUST) — "creation" (`trace/api.md`
  L252-L254).

  Creates a new `SpanContext`. Per spec L252-L254 this is the
  intended entry point (*"these methods SHOULD be the only way
  to create a SpanContext"*).
  """
  @spec new(
          trace_id :: Otel.API.Trace.TraceId.t(),
          span_id :: Otel.API.Trace.SpanId.t(),
          trace_flags :: trace_flags(),
          tracestate :: Otel.API.Trace.TraceState.t()
        ) :: t()
  def new(trace_id, span_id, trace_flags \\ 0, tracestate \\ Otel.API.Trace.TraceState.new()) do
    %__MODULE__{
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: trace_flags,
      tracestate: tracestate
    }
  end

  @doc """
  **Application** (OTel API MUST) — "IsValid" (`trace/api.md`
  L268-L271).

  Returns `true` iff both `trace_id` and `span_id` are non-zero
  (per spec's definition of "valid identifier", L231-L235).
  """
  @spec valid?(span_ctx :: t()) :: boolean()
  def valid?(%__MODULE__{trace_id: trace_id, span_id: span_id}) do
    Otel.API.Trace.TraceId.valid?(trace_id) and Otel.API.Trace.SpanId.valid?(span_id)
  end

  @doc """
  **Application** (OTel API MUST) — "IsRemote" (`trace/api.md`
  L273-L278).

  Returns `true` iff this `SpanContext` was extracted from a
  remote parent by a Propagator. Child spans generated locally
  have `is_remote: false`.
  """
  @spec remote?(span_ctx :: t()) :: boolean()
  def remote?(%__MODULE__{is_remote: is_remote}), do: is_remote

  @doc """
  **Application** (OTel API MUST) — "hex Retrieving TraceId"
  (`trace/api.md` L256-L266).

  Returns the `trace_id` as a 32-character lowercase hex string.
  """
  @spec trace_id_hex(span_ctx :: t()) :: <<_::256>>
  def trace_id_hex(%__MODULE__{trace_id: trace_id}) do
    Otel.API.Trace.TraceId.to_hex(trace_id)
  end

  @doc """
  **Application** (OTel API MUST) — "hex Retrieving SpanId"
  (`trace/api.md` L256-L266).

  Returns the `span_id` as a 16-character lowercase hex string.
  """
  @spec span_id_hex(span_ctx :: t()) :: <<_::128>>
  def span_id_hex(%__MODULE__{span_id: span_id}) do
    Otel.API.Trace.SpanId.to_hex(span_id)
  end

  @doc """
  **Application** (OTel API MUST) — "binary Retrieving TraceId"
  (`trace/api.md` L256-L266).

  Returns the `trace_id` as a 16-byte binary.
  """
  @spec trace_id_bytes(span_ctx :: t()) :: <<_::128>>
  def trace_id_bytes(%__MODULE__{trace_id: trace_id}) do
    Otel.API.Trace.TraceId.to_bytes(trace_id)
  end

  @doc """
  **Application** (OTel API MUST) — "binary Retrieving SpanId"
  (`trace/api.md` L256-L266).

  Returns the `span_id` as an 8-byte binary.
  """
  @spec span_id_bytes(span_ctx :: t()) :: <<_::64>>
  def span_id_bytes(%__MODULE__{span_id: span_id}) do
    Otel.API.Trace.SpanId.to_bytes(span_id)
  end
end
