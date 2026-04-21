defmodule Otel.API.Propagator.TextMap.TraceContext do
  @moduledoc """
  W3C TraceContext propagator.

  Implements inject and extract for the `traceparent` and `tracestate`
  headers per W3C Trace Context Level 2 specification.

  traceparent format: `VERSION-TRACEID-SPANID-TRACEFLAGS`
  - VERSION: 2 hex digits (currently "00")
  - TRACEID: 32 hex digits (128-bit, all-zeros invalid)
  - SPANID: 16 hex digits (64-bit, all-zeros invalid)
  - TRACEFLAGS: 2 hex digits (bit 0 = sampled)

  Example: `00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01`
  """

  @behaviour Otel.API.Propagator.TextMap

  @traceparent_header "traceparent"
  @tracestate_header "tracestate"

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

  @impl true
  @spec fields() :: [String.t()]
  def fields, do: [@traceparent_header, @tracestate_header]

  @spec extract_tracestate(
          carrier :: Otel.API.Propagator.TextMap.carrier(),
          getter :: Otel.API.Propagator.TextMap.getter()
        ) :: Otel.API.Trace.TraceState.t()
  defp extract_tracestate(carrier, getter) do
    case getter.(carrier, @tracestate_header) do
      nil -> Otel.API.Trace.TraceState.new()
      value -> Otel.API.Trace.TraceState.decode(String.trim(value))
    end
  end

  # --- Encoding ---

  @spec encode_traceparent(span_ctx :: Otel.API.Trace.SpanContext.t()) :: String.t()
  defp encode_traceparent(span_ctx) do
    trace_id_hex = Otel.API.Trace.SpanContext.trace_id_hex(span_ctx)
    span_id_hex = Otel.API.Trace.SpanContext.span_id_hex(span_ctx)
    flags_hex = span_ctx.trace_flags |> Integer.to_string(16) |> String.pad_leading(2, "0")
    "00-#{trace_id_hex}-#{span_id_hex}-#{flags_hex}"
  end

  # --- Decoding ---

  @spec decode_traceparent(value :: String.t()) :: Otel.API.Trace.SpanContext.t()
  defp decode_traceparent(
         <<"00-", trace_id_hex::binary-size(32), "-", span_id_hex::binary-size(16), "-",
           flags_hex::binary-size(2)>>
       ) do
    decode_span_ctx(trace_id_hex, span_id_hex, flags_hex)
  end

  # Forward-compat clause for future versions. W3C Trace Context requires a
  # trailing "-" separator before any extra bytes; version "ff" is reserved
  # and MUST be rejected.
  defp decode_traceparent(
         <<version::binary-size(2), "-", trace_id_hex::binary-size(32), "-",
           span_id_hex::binary-size(16), "-", flags_hex::binary-size(2), "-", _rest::binary>>
       )
       when version > "00" and version != "ff" do
    decode_span_ctx(trace_id_hex, span_id_hex, flags_hex)
  end

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

  @spec lowercase_hex?(hex :: String.t()) :: boolean()
  defp lowercase_hex?(hex), do: Regex.match?(~r/^[0-9a-f]+$/, hex)
end
