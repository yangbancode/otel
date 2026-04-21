defmodule Otel.API.Propagator.TextMap.TraceContext do
  @moduledoc """
  W3C Trace Context Level 2 propagator (W3C
  `20-http_request_header_format.md` §Traceparent Header
  L51-L244; OTel `context/api-propagators.md` §TextMap
  L114-L203).

  Injects and extracts the `traceparent` and `tracestate`
  HTTP headers. Wire format per W3C §Header Field Values
  L75-L96 (ABNF):

      value          = version "-" version-format
      version        = 2HEXDIGLC    ; "00" for this spec; "ff" invalid
      version-format = trace-id "-" parent-id "-" trace-flags
      trace-id       = 32HEXDIGLC   ; 16 bytes; all-zeros forbidden
      parent-id      = 16HEXDIGLC   ; 8 bytes; all-zeros forbidden
      trace-flags    = 2HEXDIGLC    ; 8 bit flags

  Example header value:

      00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01

  ## Design notes

  Two places where we diverge from
  `opentelemetry-erlang`'s `otel_propagator_trace_context.erl`
  to follow spec more strictly.

  ### 1. Lowercase-hex enforcement

  W3C §trace-id L111 *"If the trace-id value is invalid
  (for example if it contains non-allowed characters or all
  zeros), vendors MUST ignore the traceparent"* and
  §parent-id L117 *"Vendors MUST ignore the traceparent
  when the parent-id is invalid (for example, if it
  contains non-lowercase hex characters)"*.

  We call `lowercase_hex?/1` on every hex segment (version,
  trace-id, parent-id, trace-flags) to enforce `2HEXDIGLC`.
  Erlang's `binary_to_integer/2` accepts both cases, so its
  decoder silently lets uppercase hex through — we diverge
  to meet the spec MUST.

  ### 2. Flag byte preservation

  W3C §Other Flags L202 *"Vendors MUST set those to zero"*
  applies to **outgoing** traffic only. On **incoming**,
  preserving the whole byte keeps us forward-compatible with
  future flag bits (e.g. the `random-trace-id` bit already
  defined in Level 2). Erlang rejects anything other than
  `"00"`/`"01"` (`error(badarg)`); we accept the full
  `0..255` range and store the byte verbatim.

  ## Public API

  | Function | Role |
  |---|---|
  | `inject/3` | **OTel API MUST** — TextMap Inject (L155-L182) |
  | `extract/3` | **OTel API MUST** — TextMap Extract (L185-L203); MUST NOT throw on parse failure (L100-L102) |
  | `fields/0` | **OTel API** — Fields (L133-L152) |
  | `encode_traceparent/1` | **W3C header serialization** — §traceparent L75-L96 |
  | `decode_traceparent/1` | **W3C header parsing** — §traceparent L75-L96 + §Versioning L228-L244 |
  | `extract_tracestate/2` | **W3C header parsing** — `tracestate` helper |
  | `lowercase_hex?/1` | **W3C format predicate** — 2HEXDIGLC check |

  ## References

  - W3C Trace Context Level 2 §Traceparent Header: `w3c-trace-context/spec/20-http_request_header_format.md` L51-L244
  - W3C Trace Context Level 2 §Versioning: same file L227-L244
  - OTel Context §TextMap Propagator: `opentelemetry-specification/specification/context/api-propagators.md` L114-L203
  - Reference impl: `opentelemetry-erlang/apps/opentelemetry_api/src/otel_propagator_trace_context.erl`
  """

  @behaviour Otel.API.Propagator.TextMap

  @traceparent_header "traceparent"
  @tracestate_header "tracestate"

  @doc """
  **OTel API MUST** — TextMap "Inject" (`api-propagators.md`
  L155-L182) for the W3C `traceparent` and `tracestate`
  headers.

  Reads the current `SpanContext` from `ctx`. If it's valid
  (non-zero trace_id and span_id per
  `SpanContext.valid?/1`), emits a `traceparent` header and,
  when the tracestate is non-empty, a `tracestate` header.
  Invalid span contexts are not propagated — the carrier is
  returned unchanged.
  """
  @impl true
  @spec inject(
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          setter :: Otel.API.Propagator.TextMap.setter()
        ) :: Otel.API.Propagator.TextMap.carrier()
  def inject(ctx, carrier, setter) do
    span_ctx = Otel.API.Trace.current_span(ctx)

    if Otel.API.Trace.SpanContext.valid?(span_ctx) do
      carrier = setter.(@traceparent_header, encode_traceparent(span_ctx), carrier)

      if Otel.API.Trace.TraceState.empty?(span_ctx.tracestate) do
        carrier
      else
        setter.(
          @tracestate_header,
          Otel.API.Trace.TraceState.encode(span_ctx.tracestate),
          carrier
        )
      end
    else
      carrier
    end
  end

  @doc """
  **OTel API MUST** — TextMap "Extract" (`api-propagators.md`
  L185-L203) for the W3C `traceparent` and `tracestate`
  headers.

  Parses `traceparent` via `decode_traceparent/1` and folds
  `tracestate` in via `extract_tracestate/2`. The resulting
  SpanContext is marked `is_remote: true` — it came from a
  remote carrier.

  Per spec L100-L102 **MUST NOT throw on parse failure** —
  malformed headers (bad hex, zero IDs, uppercase, version
  `"ff"`, etc.) cause the original context to be returned
  unchanged via a `rescue` clause.
  """
  @impl true
  @spec extract(
          ctx :: Otel.API.Ctx.t(),
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          getter :: Otel.API.Propagator.TextMap.getter()
        ) :: Otel.API.Ctx.t()
  def extract(ctx, carrier, getter) do
    case getter.(carrier, @traceparent_header) do
      nil ->
        ctx

      traceparent_value ->
        try do
          span_ctx = decode_traceparent(String.trim(traceparent_value))
          tracestate = extract_tracestate(carrier, getter)
          span_ctx = %{span_ctx | tracestate: tracestate, is_remote: true}
          Otel.API.Trace.set_current_span(ctx, span_ctx)
        rescue
          _ -> ctx
        end
    end
  end

  @doc """
  **OTel API** — Fields (`api-propagators.md` L133-L152).

  Returns `["traceparent", "tracestate"]` — the two header
  names this propagator reads and writes.
  """
  @impl true
  @spec fields() :: [String.t()]
  def fields, do: [@traceparent_header, @tracestate_header]

  # --- Encoding ---

  @doc """
  **W3C header serialization** — encodes a `SpanContext` as
  a v00 `traceparent` header value.

  Produces `"00-<trace-id>-<parent-id>-<trace-flags>"` per
  W3C §version-format L93 ABNF. All hex segments are
  lowercase. The `trace_flags` byte is rendered as two
  lowercase hex digits regardless of which bits are set
  (this propagator does not mask reserved bits on output
  per W3C §Other Flags L202; callers controlling the span
  context are responsible for zeroing unknown bits).

  Callers are expected to have verified the span context is
  valid via `SpanContext.valid?/1` beforehand; this function
  does not validate.
  """
  @spec encode_traceparent(span_ctx :: Otel.API.Trace.SpanContext.t()) :: String.t()
  def encode_traceparent(span_ctx) do
    trace_id_hex = Otel.API.Trace.SpanContext.trace_id_hex(span_ctx)
    span_id_hex = Otel.API.Trace.SpanContext.span_id_hex(span_ctx)
    flags_hex = span_ctx.trace_flags |> Integer.to_string(16) |> String.pad_leading(2, "0")
    "00-#{trace_id_hex}-#{span_id_hex}-#{flags_hex}"
  end

  # --- Decoding ---

  @doc """
  **W3C header parsing** — parses a v00 or higher-version
  `traceparent` header value into a `SpanContext`.

  Accepts two forms per W3C §Versioning L228-L244:

  - Exactly 55 bytes with a non-`ff` version (matches v00
    and higher versions carrying no extra fields yet).
  - 55+ bytes with a trailing `-<future-fields>` suffix for
    higher versions (v01+) that added fields.

  Version `"ff"` is rejected per W3C §version L86. All hex
  segments are checked for lowercase per L83 `2HEXDIGLC`.
  A pair containing an all-zero trace-id or parent-id is
  rejected per L94-L95.

  **Raises** `MatchError` / `ArgumentError` on malformed
  input — callers needing the spec-mandated graceful
  recovery (`api-propagators.md` L100-L102) should use
  `extract/3`, which wraps this call in a `rescue` clause.
  """
  @spec decode_traceparent(value :: String.t()) :: Otel.API.Trace.SpanContext.t()
  def decode_traceparent(
        <<"00-", trace_id_hex::binary-size(32), "-", span_id_hex::binary-size(16), "-",
          flags_hex::binary-size(2)>>
      ) do
    decode_span_ctx(trace_id_hex, span_id_hex, flags_hex)
  end

  # Forward-compat clause for future versions. W3C Trace Context requires a
  # trailing "-" separator before any extra bytes; version "ff" is reserved
  # and MUST be rejected.
  def decode_traceparent(
        <<version::binary-size(2), "-", trace_id_hex::binary-size(32), "-",
          span_id_hex::binary-size(16), "-", flags_hex::binary-size(2), "-", _rest::binary>>
      )
      when version > "00" and version != "ff" do
    decode_span_ctx(trace_id_hex, span_id_hex, flags_hex)
  end

  @doc """
  **W3C header parsing** — reads the `tracestate` header
  from `carrier` via `getter` and decodes it.

  Returns an empty `TraceState` when the header is absent.
  Leading/trailing whitespace is trimmed before decoding.
  Decoding delegates to
  `Otel.API.Trace.TraceState.decode/1`, which tolerates
  malformed entries by dropping them (W3C §tracestate parse
  robustness).
  """
  @spec extract_tracestate(
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          getter :: Otel.API.Propagator.TextMap.getter()
        ) :: Otel.API.Trace.TraceState.t()
  def extract_tracestate(carrier, getter) do
    case getter.(carrier, @tracestate_header) do
      nil -> Otel.API.Trace.TraceState.new()
      value -> Otel.API.Trace.TraceState.decode(String.trim(value))
    end
  end

  # --- Format predicates ---

  @doc """
  **W3C format predicate** — returns `true` iff `hex` is a
  non-empty string of ASCII lowercase hex digits
  (`0-9a-f`).

  Used internally to enforce W3C §Header Field Values L83 /
  L94-L95 (`2HEXDIGLC` / `16HEXDIGLC` / `32HEXDIGLC`).
  Exposed so callers doing ad-hoc traceparent manipulation
  can apply the same check without duplicating the regex.
  """
  @spec lowercase_hex?(hex :: String.t()) :: boolean()
  def lowercase_hex?(hex), do: Regex.match?(~r/^[0-9a-f]+$/, hex)

  # --- Private helpers ---

  @spec decode_span_ctx(
          trace_id_hex :: String.t(),
          span_id_hex :: String.t(),
          flags_hex :: String.t()
        ) :: Otel.API.Trace.SpanContext.t()
  defp decode_span_ctx(trace_id_hex, span_id_hex, flags_hex) do
    true = lowercase_hex?(trace_id_hex)
    true = lowercase_hex?(span_id_hex)
    true = lowercase_hex?(flags_hex)

    {trace_id, ""} = Integer.parse(trace_id_hex, 16)
    {span_id, ""} = Integer.parse(span_id_hex, 16)
    {trace_flags, ""} = Integer.parse(flags_hex, 16)
    true = trace_id != 0 and span_id != 0

    %Otel.API.Trace.SpanContext{
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: trace_flags
    }
  end
end
