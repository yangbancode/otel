defmodule Otel.SDK.Trace.Tracer do
  @moduledoc """
  SDK tracer implementation.

  All configuration (sampler, id_generator, span_limits, processors,
  scope) is stored in the tracer tuple at creation time. No GenServer
  calls during span creation for performance.
  """

  @behaviour Otel.API.Trace.Tracer

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
        span = run_on_start(ctx, span, config.processors)
        Otel.SDK.Trace.SpanStorage.insert(span)
        span_ctx
    end
  end

  @spec enabled?(tracer :: Otel.API.Trace.Tracer.t(), opts :: keyword()) :: boolean()
  @impl true
  def enabled?(_tracer, _opts \\ []), do: true

  @spec run_on_start(
          ctx :: Otel.API.Ctx.t(),
          span :: Otel.SDK.Trace.Span.t(),
          processors :: [{module(), Otel.SDK.Trace.SpanProcessor.config()}]
        ) :: Otel.SDK.Trace.Span.t()
  defp run_on_start(ctx, span, processors) do
    Enum.reduce(processors, span, fn {processor, processor_config}, acc ->
      processor.on_start(ctx, acc, processor_config)
    end)
  end
end
