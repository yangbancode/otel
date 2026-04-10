defmodule Otel.API.Trace do
  @moduledoc """
  Public Trace API entry point.

  Provides functions for getting tracers, extracting/setting spans
  in context, and starting spans.
  """

  alias Otel.API.Ctx
  alias Otel.API.Trace.{Span, SpanContext, Tracer, TracerProvider}

  @typedoc "Options for span creation. See `Otel.API.Trace.Span.start_opts/0`."
  @type start_opts :: Span.start_opts()

  @span_key :"__otel.trace.span__"

  @doc """
  Returns a Tracer for the given instrumentation scope.
  """
  @spec get_tracer(String.t(), String.t(), String.t() | nil, map()) :: Otel.API.Trace.Tracer.t()
  def get_tracer(name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    TracerProvider.get_tracer(name, version, schema_url, attributes)
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

  # --- Span Creation ---

  @doc """
  Starts a new span using the implicit (process) context.

  The new span is NOT automatically set as the current span (L382).
  Use `with_span/3` for automatic context management.

  Adding attributes at creation is preferred over calling
  `Span.set_attribute/3` later, as samplers can only consider
  information already present during creation (L403).
  """
  @spec start_span(Tracer.t(), String.t(), start_opts()) :: SpanContext.t()
  def start_span(tracer, name, opts \\ []) do
    start_span(Ctx.get_current(), tracer, name, opts)
  end

  @doc """
  Starts a new span using an explicit context.

  The new span is NOT automatically set as the current span (L382).
  """
  @spec start_span(Ctx.t(), Tracer.t(), String.t(), start_opts()) :: SpanContext.t()
  def start_span(ctx, {module, _config} = tracer, name, opts) do
    module.start_span(ctx, tracer, name, opts)
  end

  @doc """
  Starts a span, sets it as current, runs a function, then ends the span.

  Uses the implicit (process) context. The span is passed to the
  function. If the function raises, the exception is recorded on
  the span and re-raised.

  Returns the function's return value.
  """
  @spec with_span(Tracer.t(), String.t(), start_opts(), (SpanContext.t() -> result)) :: result
        when result: term()
  def with_span(tracer, name, opts \\ [], fun) do
    with_span(Ctx.get_current(), tracer, name, opts, fun)
  end

  @doc """
  Starts a span using an explicit context, sets it as current, runs
  a function, then ends the span.
  """
  @spec with_span(Ctx.t(), Tracer.t(), String.t(), start_opts(), (SpanContext.t() -> result)) ::
          result
        when result: term()
  def with_span(ctx, tracer, name, opts, fun) do
    span_ctx = start_span(ctx, tracer, name, opts)

    new_ctx = set_current_span(ctx, span_ctx)
    token = Ctx.attach(new_ctx)

    try do
      fun.(span_ctx)
    catch
      kind, reason ->
        stacktrace = __STACKTRACE__

        case kind do
          :error ->
            Span.record_exception(span_ctx, reason, stacktrace)
            Span.set_status(span_ctx, :error, Exception.format(kind, reason))

          _ ->
            Span.set_status(span_ctx, :error, Exception.format(kind, reason))
        end

        :erlang.raise(kind, reason, stacktrace)
    after
      Span.end_span(span_ctx)
      Ctx.detach(token)
    end
  end
end
