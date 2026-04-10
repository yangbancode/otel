defmodule Otel.API.Trace do
  @moduledoc """
  Public Trace API entry point.

  Provides functions for getting tracers, extracting/setting spans
  in context, and starting spans.
  """

  alias Otel.API.Ctx
  alias Otel.API.Trace.{SpanContext, TracerProvider}

  @span_key :otel_trace_span

  @doc """
  Returns a Tracer for the given instrumentation scope.
  """
  @spec get_tracer(String.t(), String.t(), String.t() | nil) :: Otel.API.Trace.Tracer.t()
  def get_tracer(name, version \\ "", schema_url \\ nil) do
    TracerProvider.get_tracer(name, version, schema_url)
  end

  @doc """
  Extracts the current Span's SpanContext from the given context.
  """
  @spec current_span(Ctx.t()) :: SpanContext.t()
  def current_span(ctx) do
    Ctx.get_value(ctx, @span_key, %SpanContext{})
  end

  @doc """
  Returns a new context with the given SpanContext set as the current span.
  """
  @spec set_current_span(Ctx.t(), SpanContext.t()) :: Ctx.t()
  def set_current_span(ctx, span_ctx) do
    Ctx.set_value(ctx, @span_key, span_ctx)
  end

  @doc """
  Gets the current span from the implicit (process) context.
  """
  @spec current_span() :: SpanContext.t()
  def current_span do
    Ctx.get_value(@span_key, %SpanContext{})
  end

  @doc """
  Sets the span in the implicit (process) context.
  """
  @spec set_current_span(SpanContext.t()) :: :ok
  def set_current_span(span_ctx) do
    Ctx.set_value(@span_key, span_ctx)
  end
end
