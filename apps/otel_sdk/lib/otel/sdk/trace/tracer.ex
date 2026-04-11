defmodule Otel.SDK.Trace.Tracer do
  @moduledoc """
  SDK tracer implementation.

  Delegates span creation to the SDK pipeline (sampling, ID generation,
  processor notification). Full implementation in SDK Span Creation Flow
  decision.
  """

  @behaviour Otel.API.Trace.Tracer

  @spec start_span(Otel.API.Ctx.t(), Otel.API.Trace.Tracer.t(), String.t(), keyword()) ::
          Otel.API.Trace.SpanContext.t()
  @impl true
  def start_span(_ctx, _tracer, _name, _opts) do
    # Stub — full implementation in SDK Span Creation Flow decision
    %Otel.API.Trace.SpanContext{}
  end

  @spec enabled?(Otel.API.Trace.Tracer.t(), keyword()) :: boolean()
  @impl true
  def enabled?(_tracer, _opts \\ []), do: true
end
