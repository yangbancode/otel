defmodule Otel.API.Trace.Noop do
  @moduledoc """
  No-op tracer used when no SDK is installed.

  Returns the parent SpanContext from context if available,
  otherwise returns an invalid SpanContext with all-zero IDs.
  """

  @behaviour Otel.API.Trace.Tracer

  alias Otel.API.Trace.SpanContext

  @invalid_ctx %SpanContext{}

  @impl true
  def start_span(ctx, _tracer, _name, _opts) do
    case Map.get(ctx, :span, nil) do
      %SpanContext{trace_id: trace_id} = parent when trace_id != 0 ->
        parent

      _ ->
        @invalid_ctx
    end
  end

  @impl true
  def enabled?(_tracer), do: false
end
