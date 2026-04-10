defmodule Otel.API.Trace.Span do
  @moduledoc """
  Span operations for the Trace API.

  A Span represents a single operation within a trace. All mutating
  operations are no-ops after the span has ended (L368). Operations on
  non-recording spans are silently ignored.

  At the API level (without SDK), all operations are no-ops.
  The SDK overrides these via the tracer module dispatch.
  """

  alias Otel.API.Trace.SpanContext

  @type status_code :: :unset | :ok | :error

  @doc """
  Returns the SpanContext for the given span.

  The returned value is the same for the entire span lifetime (L460).
  """
  @spec get_context(SpanContext.t()) :: SpanContext.t()
  def get_context(%SpanContext{} = span_ctx), do: span_ctx

  @doc """
  Returns whether the span is recording.

  IsRecording is independent of the sampled flag in trace_flags (L465-476).
  Without SDK, always returns false. The SDK sets the actual recording
  state based on sampler decisions.
  """
  @spec recording?(SpanContext.t()) :: boolean()
  def recording?(%SpanContext{}), do: false

  @doc """
  Sets a single attribute on the span.

  Ignored if the span is not recording. Setting an attribute with
  the same key as an existing attribute overwrites the value.
  """
  @spec set_attribute(SpanContext.t(), String.t() | atom(), term()) :: :ok
  def set_attribute(%SpanContext{}, _key, _value), do: :ok

  @doc """
  Sets multiple attributes on the span.
  """
  @spec set_attributes(SpanContext.t(), map() | [{String.t() | atom(), term()}]) :: :ok
  def set_attributes(%SpanContext{}, _attributes), do: :ok

  @doc """
  Adds an event to the span.

  Events have a name, optional attributes, and an optional timestamp.
  If no timestamp is provided, the current time is used (L537-539).
  Events preserve insertion order.

  Options:
  - `:time` — custom timestamp (integer, nanoseconds)
  - `:attributes` — event attributes (map)
  """
  @spec add_event(SpanContext.t(), String.t() | atom(), keyword()) :: :ok
  def add_event(%SpanContext{}, _name, _opts \\ []), do: :ok

  @doc """
  Adds a link to another span after creation.

  Adding links at span creation is preferred over calling this later.
  """
  @spec add_link(SpanContext.t(), SpanContext.t(), map()) :: :ok
  def add_link(%SpanContext{}, _linked_ctx, _attributes \\ %{}), do: :ok

  @doc """
  Sets the status of the span.

  Status code is one of `:unset`, `:ok`, or `:error`.
  Description is only used with `:error` status and MUST be
  ignored for `:ok` and `:unset` (L599).

  Status priority (L619): once set to `:ok`, the status is final.
  `:error` takes precedence over `:unset`. Attempting to set
  `:unset` is always ignored (L603).
  """
  @spec set_status(SpanContext.t(), status_code(), String.t()) :: :ok
  def set_status(%SpanContext{}, _code, _description \\ ""), do: :ok

  @doc """
  Updates the name of the span.
  """
  @spec update_name(SpanContext.t(), String.t()) :: :ok
  def update_name(%SpanContext{}, _name), do: :ok

  @doc """
  Ends the span.

  After this call, the span is no longer recording and all
  subsequent operations are silently ignored (L652). If no timestamp
  is provided, the current time is used (L673).

  This operation MUST NOT perform blocking I/O (L677).
  """
  @spec end_span(SpanContext.t(), integer() | nil) :: :ok
  def end_span(%SpanContext{}, _timestamp \\ nil), do: :ok

  @doc """
  Records an exception as an event on the span.

  Creates an event named `"exception"` with semantic convention
  attributes (L693):
  - `exception.type`
  - `exception.message` (from the exception struct)
  - `exception.stacktrace`

  Additional attributes can be provided and are merged (L697).
  """
  @spec record_exception(SpanContext.t(), Exception.t(), list(), map()) :: :ok
  def record_exception(
        %SpanContext{},
        _exception,
        _stacktrace \\ [],
        _attributes \\ %{}
      ),
      do: :ok
end
