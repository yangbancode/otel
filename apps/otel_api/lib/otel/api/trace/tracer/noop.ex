defmodule Otel.API.Trace.Tracer.Noop do
  @moduledoc """
  No-op tracer used when no SDK is installed.

  Returns the parent SpanContext from context if available,
  otherwise returns an invalid SpanContext with all-zero IDs.
  """

  @behaviour Otel.API.Trace.Tracer

  @invalid_ctx %Otel.API.Trace.SpanContext{}

  @impl true
  def start_span(ctx, _tracer, _name, _opts) do
    case Otel.API.Trace.current_span(ctx) do
      %Otel.API.Trace.SpanContext{trace_id: trace_id} = parent when trace_id != 0 ->
        parent

      _ ->
        @invalid_ctx
    end
  end

  @impl true
  def enabled?(_tracer, _opts \\ []), do: false
end
