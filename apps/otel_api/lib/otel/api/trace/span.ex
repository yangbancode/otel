defmodule Otel.API.Trace.Span do
  @moduledoc """
  Span operations for the Trace API.

  A Span represents a single operation within a trace. All mutating
  operations are no-ops after the span has ended (L368). Operations on
  non-recording spans are silently ignored.

  At the API level (without SDK), all operations are no-ops.
  The SDK overrides these via the tracer module dispatch.
  """

  @type status_code :: :unset | :ok | :error

  @type start_opts :: [
          kind: Otel.API.Trace.SpanKind.t(),
          attributes: map(),
          links: [{Otel.API.Trace.SpanContext.t(), map()}],
          start_time: integer(),
          is_root: boolean()
        ]

  @doc """
  Returns the SpanContext for the given span.

  The returned value is the same for the entire span lifetime (L460).
  """
  @spec get_context(span_ctx :: Otel.API.Trace.SpanContext.t()) :: Otel.API.Trace.SpanContext.t()
  def get_context(%Otel.API.Trace.SpanContext{} = span_ctx), do: span_ctx

  @doc """
  Returns whether the span is recording.

  IsRecording is independent of the sampled flag in trace_flags (L465-476).
  Without SDK, always returns false. The SDK sets the actual recording
  state based on sampler decisions.
  """
  @spec recording?(span_ctx :: Otel.API.Trace.SpanContext.t()) :: boolean()
  def recording?(%Otel.API.Trace.SpanContext{}), do: false

  @doc """
  Sets a single attribute on the span.

  Ignored if the span is not recording. Setting an attribute with
  the same key as an existing attribute overwrites the value.
  """
  @spec set_attribute(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          key :: String.t() | atom(),
          value :: term()
        ) :: :ok
  def set_attribute(%Otel.API.Trace.SpanContext{}, _key, _value), do: :ok

  @doc """
  Sets multiple attributes on the span.
  """
  @spec set_attributes(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes :: map() | [{String.t() | atom(), term()}]
        ) ::
          :ok
  def set_attributes(%Otel.API.Trace.SpanContext{}, _attributes), do: :ok

  @doc """
  Adds an event to the span.

  Events have a name, optional attributes, and an optional timestamp.
  If no timestamp is provided, the current time is used (L537-539).
  Events preserve insertion order.

  Options:
  - `:time` — custom timestamp (integer, nanoseconds)
  - `:attributes` — event attributes (map)
  """
  @spec add_event(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          name :: String.t() | atom(),
          opts :: keyword()
        ) :: :ok
  def add_event(%Otel.API.Trace.SpanContext{}, _name, _opts \\ []), do: :ok

  @doc """
  Adds a link to another span after creation.

  Adding links at span creation is preferred over calling this later.
  """
  @spec add_link(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          linked_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes :: map()
        ) :: :ok
  def add_link(%Otel.API.Trace.SpanContext{}, _linked_ctx, _attributes \\ %{}), do: :ok

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
          code :: status_code(),
          description :: String.t()
        ) :: :ok
  def set_status(%Otel.API.Trace.SpanContext{}, _code, _description \\ ""), do: :ok

  @doc """
  Updates the name of the span.
  """
  @spec update_name(span_ctx :: Otel.API.Trace.SpanContext.t(), name :: String.t()) :: :ok
  def update_name(%Otel.API.Trace.SpanContext{}, _name), do: :ok

  @doc """
  Ends the span.

  After this call, the span is no longer recording and all
  subsequent operations are silently ignored (L652). If no timestamp
  is provided, the current time is used (L673).

  This operation MUST NOT perform blocking I/O (L677).
  """
  @spec end_span(span_ctx :: Otel.API.Trace.SpanContext.t(), timestamp :: integer() | nil) :: :ok
  def end_span(%Otel.API.Trace.SpanContext{}, _timestamp \\ nil), do: :ok

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
          attributes :: map()
        ) :: :ok
  def record_exception(
        %Otel.API.Trace.SpanContext{},
        _exception,
        _stacktrace \\ [],
        _attributes \\ %{}
      ),
      do: :ok
end
