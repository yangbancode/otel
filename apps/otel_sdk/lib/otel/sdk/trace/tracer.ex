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
          opts :: Otel.API.Trace.Span.start_opts()
        ) :: Otel.API.Trace.SpanContext.t()
  @impl true
  def start_span(ctx, {__MODULE__, config}, name, opts) do
    {span_ctx, span} =
      Otel.SDK.Trace.Span.start_span(
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
        span = %{
          span
          | instrumentation_scope: config.scope,
            span_limits: config.span_limits,
            processors: config.processors
        }

        span = run_on_start(ctx, span, config.processors)
        Otel.SDK.Trace.SpanStorage.insert(span)
        span_ctx
    end
  end

  @spec with_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: Otel.API.Trace.Span.start_opts(),
          fun :: (Otel.API.Trace.SpanContext.t() -> result)
        ) :: result
        when result: term()
  @impl true
  def with_span(ctx, tracer, name, opts, fun) do
    span_ctx = start_span(ctx, tracer, name, opts)
    new_ctx = Otel.API.Trace.set_current_span(ctx, span_ctx)
    token = Otel.API.Ctx.attach(new_ctx)

    try do
      fun.(span_ctx)
    catch
      kind, reason ->
        stacktrace = __STACKTRACE__

        case kind do
          :error ->
            normalized = Exception.normalize(:error, reason, stacktrace)
            Otel.API.Trace.Span.record_exception(span_ctx, normalized, stacktrace)

            Otel.API.Trace.Span.set_status(
              span_ctx,
              Otel.API.Trace.Status.new(:error, Exception.message(normalized))
            )

          _ ->
            Otel.API.Trace.Span.set_status(
              span_ctx,
              Otel.API.Trace.Status.new(:error, Exception.format(kind, reason))
            )
        end

        :erlang.raise(kind, reason, stacktrace)
    after
      Otel.API.Trace.Span.end_span(span_ctx)
      Otel.API.Ctx.detach(token)
    end
  end

  # Spec `trace/sdk.md` L223-L227 (Status: Development) —
  # *"Enabled MUST return false when either: there are no
  # registered SpanProcessors, Tracer is disabled
  # (TracerConfig.enabled is false). Otherwise, it SHOULD
  # return true."* TracerConfig is itself Development and
  # not yet implemented (see span_processor.ex `## Design
  # notes`); we honour the no-processors leg only.
  @spec enabled?(
          tracer :: Otel.API.Trace.Tracer.t(),
          opts :: Otel.API.Trace.Tracer.enabled_opts()
        ) :: boolean()
  @impl true
  def enabled?({__MODULE__, config}, _opts \\ []) do
    config.processors != []
  end

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
