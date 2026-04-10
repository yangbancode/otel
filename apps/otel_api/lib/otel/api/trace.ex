defmodule Otel.API.Trace do
  @moduledoc """
  Public Trace API entry point.

  Provides functions for getting tracers, extracting/setting spans
  in context, and starting spans.
  """

  @typedoc "Options for span creation. See `Otel.API.Trace.Span.start_opts/0`."
  @type start_opts :: Otel.API.Trace.Span.start_opts()

  @span_key :"__otel.trace.span__"

  @doc """
  Returns a Tracer for the given instrumentation scope.
  """
  @spec get_tracer(
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: map()
        ) :: Otel.API.Trace.Tracer.t()
  def get_tracer(name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    Otel.API.Trace.TracerProvider.get_tracer(name, version, schema_url, attributes)
  end

  @doc """
  Extracts the current Span's SpanContext from the given context.
  """
  @spec current_span(ctx :: Otel.API.Ctx.t()) :: Otel.API.Trace.SpanContext.t()
  def current_span(ctx) do
    Otel.API.Ctx.get_value(ctx, @span_key, %Otel.API.Trace.SpanContext{})
  end

  @doc """
  Returns a new context with the given SpanContext set as the current span.
  """
  @spec set_current_span(ctx :: Otel.API.Ctx.t(), span_ctx :: Otel.API.Trace.SpanContext.t()) ::
          Otel.API.Ctx.t()
  def set_current_span(ctx, span_ctx) do
    Otel.API.Ctx.set_value(ctx, @span_key, span_ctx)
  end

  @doc """
  Gets the current span from the implicit (process) context.
  """
  @spec current_span() :: Otel.API.Trace.SpanContext.t()
  def current_span do
    Otel.API.Ctx.get_value(@span_key, %Otel.API.Trace.SpanContext{})
  end

  @doc """
  Sets the span in the implicit (process) context.
  """
  @spec set_current_span(span_ctx :: Otel.API.Trace.SpanContext.t()) :: :ok
  def set_current_span(span_ctx) do
    Otel.API.Ctx.set_value(@span_key, span_ctx)
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
  @spec start_span(tracer :: Otel.API.Trace.Tracer.t(), name :: String.t(), opts :: start_opts()) ::
          Otel.API.Trace.SpanContext.t()
  def start_span(tracer, name, opts \\ []) do
    start_span(Otel.API.Ctx.get_current(), tracer, name, opts)
  end

  @doc """
  Starts a new span using an explicit context.

  The new span is NOT automatically set as the current span (L382).
  """
  @spec start_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: start_opts()
        ) ::
          Otel.API.Trace.SpanContext.t()
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
  @spec with_span(
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: start_opts(),
          fun :: (Otel.API.Trace.SpanContext.t() -> result)
        ) :: result
        when result: term()
  def with_span(tracer, name, opts \\ [], fun) do
    with_span(Otel.API.Ctx.get_current(), tracer, name, opts, fun)
  end

  @doc """
  Starts a span using an explicit context, sets it as current, runs
  a function, then ends the span.
  """
  @spec with_span(
          ctx :: Otel.API.Ctx.t(),
          tracer :: Otel.API.Trace.Tracer.t(),
          name :: String.t(),
          opts :: start_opts(),
          fun :: (Otel.API.Trace.SpanContext.t() -> result)
        ) ::
          result
        when result: term()
  def with_span(ctx, tracer, name, opts, fun) do
    span_ctx = start_span(ctx, tracer, name, opts)

    new_ctx = set_current_span(ctx, span_ctx)
    token = Otel.API.Ctx.attach(new_ctx)

    try do
      fun.(span_ctx)
    catch
      kind, reason ->
        stacktrace = __STACKTRACE__

        case kind do
          :error ->
            Otel.API.Trace.Span.record_exception(span_ctx, reason, stacktrace)
            Otel.API.Trace.Span.set_status(span_ctx, :error, Exception.format(kind, reason))

          _ ->
            Otel.API.Trace.Span.set_status(span_ctx, :error, Exception.format(kind, reason))
        end

        :erlang.raise(kind, reason, stacktrace)
    after
      Otel.API.Trace.Span.end_span(span_ctx)
      Otel.API.Ctx.detach(token)
    end
  end
end
