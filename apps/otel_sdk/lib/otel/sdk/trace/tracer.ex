defmodule Otel.SDK.Trace.Tracer do
  @moduledoc """
  SDK tracer implementation.

  Reads configuration from TracerProvider and delegates span creation
  to SpanCreator. Recording spans are stored in SpanStorage.
  """

  @behaviour Otel.API.Trace.Tracer

  @spec start_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: Otel.API.Trace.SpanContext.t()
  @impl true
  def start_span(ctx, {__MODULE__, %{provider: provider, scope: scope}}, name, opts) do
    config = Otel.SDK.Trace.TracerProvider.config(provider)
    sampler = Otel.SDK.Trace.Sampler.new(config.sampler)

    {span_ctx, span} =
      Otel.SDK.Trace.SpanCreator.start_span(
        ctx,
        name,
        sampler,
        config.id_generator,
        opts
      )

    if span do
      span = %{span | instrumentation_scope: scope}
      Otel.SDK.Trace.SpanStorage.insert(span)
    end

    span_ctx
  end

  @spec enabled?(tracer :: Otel.API.Trace.Tracer.t(), opts :: keyword()) :: boolean()
  @impl true
  def enabled?(_tracer, _opts \\ []), do: true
end
