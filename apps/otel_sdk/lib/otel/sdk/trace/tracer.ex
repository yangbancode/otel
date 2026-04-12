defmodule Otel.SDK.Trace.Tracer do
  @moduledoc """
  SDK tracer implementation.

  All configuration (sampler, id_generator, span_limits, scope) is
  stored in the tracer tuple at creation time. No GenServer calls
  during span creation for performance.
  """

  @behaviour Otel.API.Trace.Tracer

  @noop_ctx %Otel.API.Trace.SpanContext{}

  @spec start_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: Otel.API.Trace.SpanContext.t()
  @impl true
  def start_span(ctx, {__MODULE__, config}, name, opts) do
    {span_ctx, span} =
      Otel.SDK.Trace.SpanCreator.start_span(
        ctx,
        name,
        config.sampler,
        config.id_generator,
        config.span_limits,
        opts
      )

    case span do
      nil ->
        span_ctx

      span ->
        span = %{span | instrumentation_scope: config.scope}

        try do
          Otel.SDK.Trace.SpanStorage.insert(span)
          span_ctx
        rescue
          ArgumentError -> @noop_ctx
        end
    end
  end

  @spec enabled?(tracer :: Otel.API.Trace.Tracer.t(), opts :: keyword()) :: boolean()
  @impl true
  def enabled?(_tracer, _opts \\ []), do: true
end
