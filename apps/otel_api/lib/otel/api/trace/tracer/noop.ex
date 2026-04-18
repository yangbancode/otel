defmodule Otel.API.Trace.Tracer.Noop do
  @moduledoc """
  No-op tracer used when no SDK is installed.

  Returns the parent SpanContext from context if available,
  otherwise returns an invalid SpanContext with all-zero IDs.
  """

  @behaviour Otel.API.Trace.Tracer

  @invalid_ctx %Otel.API.Trace.SpanContext{}

  @spec start_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: Otel.API.Trace.Span.start_opts()
        ) :: Otel.API.Trace.SpanContext.t()
  @impl true
  def start_span(ctx, _tracer, _name, _opts) do
    case Otel.API.Trace.current_span(ctx) do
      %Otel.API.Trace.SpanContext{trace_id: trace_id} = parent when trace_id != 0 ->
        parent

      _ ->
        @invalid_ctx
    end
  end

  @spec enabled?(
          tracer :: Otel.API.Trace.Tracer.t(),
          opts :: Otel.API.Trace.Tracer.enabled_opts()
        ) :: boolean()
  @impl true
  def enabled?(_tracer, _opts \\ []), do: false
end
