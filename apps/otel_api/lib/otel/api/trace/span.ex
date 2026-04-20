defmodule Otel.API.Trace.Span do
  @moduledoc """
  Span operations for the Trace API.

  A Span represents a single operation within a trace. All mutating
  operations are no-ops after the span has ended (L368). Operations on
  non-recording spans are silently ignored.

  At the API level (without SDK), all operations are no-ops.
  When an SDK is installed, it registers a span module via
  `set_module/1` and operations are dispatched to it.

  All functions are safe for concurrent use.
  """

  use Otel.API.Common.Types

  @type start_opts :: [
          kind: Otel.API.Trace.SpanKind.t(),
          attributes: %{String.t() => primitive() | [primitive()]},
          links: [Otel.API.Trace.Link.t()],
          start_time: integer(),
          is_root: boolean()
        ]

  @module_key {__MODULE__, :module}

  @doc """
  Registers the SDK span operations module.
  """
  @spec set_module(module :: module()) :: :ok
  def set_module(module) when is_atom(module) do
    :persistent_term.put(@module_key, module)
    :ok
  end

  @doc """
  Returns the registered SDK span operations module, or `nil`.
  """
  @spec get_module() :: module() | nil
  def get_module do
    :persistent_term.get(@module_key, nil)
  end

  @doc """
  Returns the SpanContext for the given span.

  The returned value is the same for the entire span lifetime (L460).
  """
  @spec get_context(span_ctx :: Otel.API.Trace.SpanContext.t()) :: Otel.API.Trace.SpanContext.t()
  def get_context(%Otel.API.Trace.SpanContext{} = span_ctx), do: span_ctx

  @doc """
  Returns whether the span is recording.

  IsRecording is independent of the sampled flag in trace_flags (L465-476).
  Without SDK, always returns false. The SDK checks recording state
  via span storage.
  """
  @spec recording?(span_ctx :: Otel.API.Trace.SpanContext.t()) :: boolean()
  def recording?(%Otel.API.Trace.SpanContext{} = span_ctx) do
    case get_module() do
      nil -> false
      module -> module.recording?(span_ctx)
    end
  end

  @doc """
  Sets a single attribute on the span.

  Ignored if the span is not recording. Setting an attribute with
  the same key as an existing attribute overwrites the value.
  """
  @spec set_attribute(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          key :: String.t(),
          value :: primitive() | [primitive()]
        ) :: :ok
  def set_attribute(%Otel.API.Trace.SpanContext{} = span_ctx, key, value) do
    case get_module() do
      nil -> :ok
      module -> module.set_attribute(span_ctx, key, value)
    end
  end

  @doc """
  Sets multiple attributes on the span.
  """
  @spec set_attributes(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) ::
          :ok
  def set_attributes(%Otel.API.Trace.SpanContext{} = span_ctx, attributes) do
    case get_module() do
      nil -> :ok
      module -> module.set_attributes(span_ctx, attributes)
    end
  end

  @doc """
  Adds an event to the span.

  Events preserve insertion order. The caller constructs the event with
  `Otel.API.Trace.Event.new/3` — the timestamp defaults to the current
  system time if omitted there.
  """
  @spec add_event(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          event :: Otel.API.Trace.Event.t()
        ) :: :ok
  def add_event(%Otel.API.Trace.SpanContext{} = span_ctx, %Otel.API.Trace.Event{} = event) do
    case get_module() do
      nil -> :ok
      module -> module.add_event(span_ctx, event)
    end
  end

  @doc """
  Adds a link to another span after creation.

  Adding links at span creation is preferred over calling this later.
  """
  @spec add_link(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          link :: Otel.API.Trace.Link.t()
        ) :: :ok
  def add_link(%Otel.API.Trace.SpanContext{} = span_ctx, %Otel.API.Trace.Link{} = link) do
    case get_module() do
      nil -> :ok
      module -> module.add_link(span_ctx, link)
    end
  end

  @doc """
  Sets the status of the span.

  Status code is one of `:unset`, `:ok`, or `:error`.
  Description is only used with `:error` status and MUST be
  ignored for `:ok` and `:unset` (L599).

  Status priority (L619): once set to `:ok`, the status is final.
  `:error` takes precedence over `:unset`. Attempting to set
  `:unset` is always ignored (L603).
  """
  @spec set_status(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          status :: Otel.API.Trace.Status.t()
        ) :: :ok
  def set_status(%Otel.API.Trace.SpanContext{} = span_ctx, %Otel.API.Trace.Status{} = status) do
    case get_module() do
      nil -> :ok
      module -> module.set_status(span_ctx, status)
    end
  end

  @doc """
  Updates the name of the span.
  """
  @spec update_name(span_ctx :: Otel.API.Trace.SpanContext.t(), name :: String.t()) :: :ok
  def update_name(%Otel.API.Trace.SpanContext{} = span_ctx, name) do
    case get_module() do
      nil -> :ok
      module -> module.update_name(span_ctx, name)
    end
  end

  @doc """
  Ends the span.

  After this call, the span is no longer recording and all
  subsequent operations are silently ignored (L652). If no timestamp
  is provided, the current time is used (L673).

  This operation MUST NOT perform blocking I/O (L677).
  """
  @spec end_span(span_ctx :: Otel.API.Trace.SpanContext.t(), timestamp :: integer() | nil) :: :ok
  def end_span(%Otel.API.Trace.SpanContext{} = span_ctx, timestamp \\ nil) do
    case get_module() do
      nil -> :ok
      module -> module.end_span(span_ctx, timestamp)
    end
  end

  @doc """
  Records an exception as an event on the span.

  Creates an event named `"exception"` with semantic convention
  attributes (L693):
  - `exception.type`
  - `exception.message` (from the exception struct)
  - `exception.stacktrace`

  Additional attributes can be provided and are merged (L697).
  """
  @spec record_exception(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          exception :: Exception.t(),
          stacktrace :: list(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) :: :ok
  def record_exception(
        %Otel.API.Trace.SpanContext{} = span_ctx,
        exception,
        stacktrace \\ [],
        attributes \\ %{}
      ) do
    case get_module() do
      nil -> :ok
      module -> module.record_exception(span_ctx, exception, stacktrace, attributes)
    end
  end
end
