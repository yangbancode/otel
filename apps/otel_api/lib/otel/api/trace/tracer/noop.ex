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
          opts :: keyword()
        ) :: Otel.API.Trace.SpanContext.t()
  @impl true
  def start_span(ctx, _tracer, _name, _opts) do
    parent = Otel.API.Trace.current_span(ctx)

    if Otel.API.Trace.SpanContext.valid?(parent) do
      parent
    else
      @invalid_ctx
    end
  end

  @spec enabled?(tracer :: Otel.API.Trace.Tracer.t(), opts :: keyword()) :: boolean()
  @impl true
  def enabled?(_tracer, _opts \\ []), do: false
end
