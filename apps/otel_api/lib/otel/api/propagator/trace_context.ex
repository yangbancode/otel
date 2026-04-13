defmodule Otel.API.Propagator.TraceContext do
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

      if Otel.API.Trace.TraceState.size(span_ctx.tracestate) > 0 do
        setter.(
          @tracestate_header,
          Otel.API.Trace.TraceState.encode(span_ctx.tracestate),
          carrier
        )
      else
        carrier
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
    with traceparent_value when traceparent_value != nil <- getter.(carrier, @traceparent_header),
         %Otel.API.Trace.SpanContext{} = span_ctx <-
           decode_traceparent(String.trim(traceparent_value)) do
      tracestate = extract_tracestate(carrier, getter)
      span_ctx = %{span_ctx | tracestate: tracestate, is_remote: true}
      Otel.API.Trace.set_current_span(ctx, span_ctx)
    else
      _ -> ctx
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
      nil -> %Otel.API.Trace.TraceState{}
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

  @spec decode_traceparent(value :: String.t()) :: Otel.API.Trace.SpanContext.t() | nil
  defp decode_traceparent(
         <<version::binary-size(2), "-", trace_id_hex::binary-size(32), "-",
           span_id_hex::binary-size(16), "-", flags_hex::binary-size(2), _rest::binary>>
       ) do
    with true <- version >= "00" and version != "ff",
         {trace_id, ""} <- Integer.parse(trace_id_hex, 16),
         {span_id, ""} <- Integer.parse(span_id_hex, 16),
         {trace_flags, ""} <- Integer.parse(flags_hex, 16),
         true <- trace_id != 0,
         true <- span_id != 0 do
      %Otel.API.Trace.SpanContext{
        trace_id: trace_id,
        span_id: span_id,
        trace_flags: trace_flags
      }
    else
      _ -> nil
    end
  end

  defp decode_traceparent(_), do: nil
end
