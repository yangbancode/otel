defmodule Otel.API.Trace.Tracer.Noop do
  @moduledoc """
  No-op tracer used when no SDK is installed.

  Returns the parent SpanContext from context if available,
  otherwise returns an invalid SpanContext with all-zero IDs.
  """

  @behaviour Otel.API.Trace.Tracer

  @invalid_ctx %Otel.API.Trace.SpanContext{}

  @spec start_span(Otel.API.Ctx.t(), Otel.API.Trace.Tracer.t(), String.t(), keyword()) ::
          Otel.API.Trace.SpanContext.t()
  @impl true
  def start_span(ctx, _tracer, _name, _opts) do
    case Otel.API.Trace.current_span(ctx) do
      %Otel.API.Trace.SpanContext{trace_id: trace_id} = parent when trace_id != 0 ->
        parent

      _ ->
        @invalid_ctx
    end
  end

  @spec enabled?(Otel.API.Trace.Tracer.t(), keyword()) :: boolean()
  @impl true
  def enabled?(_tracer, _opts \\ []), do: false
end
