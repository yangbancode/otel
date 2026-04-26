defmodule Otel.SDK.Trace.Span do
  @moduledoc """
  SDK span record — data + lifecycle operations.

  Holds all span data during its lifecycle. Creation is a pure
  operation; all mutating operations read/write the span in ETS via
  `SpanStorage` and are no-ops when the span is not in ETS (already
  ended or dropped).

  Registered as the global span module on SDK application start;
  the API layer's `Otel.API.Trace.Span` dispatches to the functions
  defined here via the `Otel.API.Trace.Span` behaviour.
  """

  use Otel.API.Common.Types

  @behaviour Otel.API.Trace.Span

  @type t :: %__MODULE__{
          trace_id: Otel.API.Trace.TraceId.t(),
          span_id: Otel.API.Trace.SpanId.t(),
          tracestate: Otel.API.Trace.TraceState.t(),
          parent_span_id: Otel.API.Trace.SpanId.t() | nil,
          parent_span_is_remote: boolean() | nil,
          name: String.t(),
          kind: Otel.API.Trace.SpanKind.t(),
          start_time: non_neg_integer(),
          end_time: non_neg_integer() | nil,
          attributes: %{String.t() => primitive() | [primitive()]},
          events: [Otel.API.Trace.Event.t()],
          links: [Otel.API.Trace.Link.t()],
          status: Otel.API.Trace.Status.t(),
          trace_flags: Otel.API.Trace.SpanContext.trace_flags(),
          is_recording: boolean(),
          instrumentation_scope: Otel.API.InstrumentationScope.t() | nil,
          span_limits: Otel.SDK.Trace.SpanLimits.t(),
          processors: [{module(), term()}]
        }

  defstruct [
    :trace_id,
    :span_id,
    :parent_span_id,
    :parent_span_is_remote,
    :name,
    :end_time,
    :instrumentation_scope,
    tracestate: Otel.API.Trace.TraceState.new(),
    kind: :internal,
    start_time: 0,
    attributes: %{},
    events: [],
    links: [],
    status: %Otel.API.Trace.Status{},
    trace_flags: 0,
    is_recording: true,
    span_limits: %Otel.SDK.Trace.SpanLimits{},
    processors: []
  ]

  # --- Creation ---

  @doc """
  Creates a span following the SDK creation flow (spec L339).

  Returns `{span_ctx, span | nil}` where span is nil for dropped spans.
  """
  @spec start_span(
          ctx :: Otel.API.Ctx.t(),
          name :: String.t(),
          sampler :: Otel.SDK.Trace.Sampler.t(),
          id_generator :: module(),
          span_limits :: Otel.SDK.Trace.SpanLimits.t(),
          opts :: Otel.API.Trace.Span.start_opts()
        ) :: {Otel.API.Trace.SpanContext.t(), t() | nil}
  def start_span(ctx, name, sampler, id_generator, span_limits, opts) do
    kind = Keyword.get(opts, :kind, :internal)
    attributes = Keyword.get(opts, :attributes, %{})
    links = Keyword.get(opts, :links, [])
    start_time = Keyword.get(opts, :start_time, System.system_time(:nanosecond))

    {span_ctx, parent_span_id, parent_is_remote} = new_span_ctx(ctx, id_generator, opts)

    trace_id = span_ctx.trace_id
    span_id = span_ctx.span_id

    {trace_flags, is_recording, sampler_attributes, tracestate} =
      sample(ctx, sampler, trace_id, links, name, kind, attributes)

    span_ctx = %Otel.API.Trace.SpanContext{
      span_ctx
      | trace_flags: trace_flags,
        tracestate: tracestate
    }

    if is_recording do
      merged_attributes =
        attributes
        |> Map.merge(sampler_attributes)
        |> apply_attribute_limits(
          span_limits.attribute_count_limit,
          span_limits.attribute_value_length_limit
        )

      limited_links =
        links
        |> Enum.take(span_limits.link_count_limit)
        |> Enum.map(fn %Otel.API.Trace.Link{} = link ->
          %{
            link
            | attributes:
                apply_attribute_limits(
                  link.attributes,
                  span_limits.attribute_per_link_limit,
                  span_limits.attribute_value_length_limit
                )
          }
        end)

      span = %__MODULE__{
        trace_id: trace_id,
        span_id: span_id,
        tracestate: tracestate,
        parent_span_id: parent_span_id,
        parent_span_is_remote: parent_is_remote,
        name: name,
        kind: kind,
        start_time: start_time,
        attributes: merged_attributes,
        events: [],
        links: limited_links,
        trace_flags: trace_flags,
        is_recording: true
      }

      {span_ctx, span}
    else
      {span_ctx, nil}
    end
  end

  # --- Lifecycle operations (ETS-backed) ---

  @doc """
  Returns whether the span is currently recording.
  """
  @impl true
  @spec recording?(span_ctx :: Otel.API.Trace.SpanContext.t()) :: boolean()
  def recording?(%Otel.API.Trace.SpanContext{span_id: span_id}) do
    Otel.SDK.Trace.SpanStorage.get(span_id) != nil
  end

  @doc """
  Sets a single attribute on the span.
  """
  @impl true
  @spec set_attribute(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          key :: String.t(),
          value :: term()
        ) :: :ok
  def set_attribute(%Otel.API.Trace.SpanContext{span_id: span_id}, key, value) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        limits = span.span_limits
        value = truncate_value(value, limits.attribute_value_length_limit)
        attributes = put_attribute(span.attributes, key, value, limits.attribute_count_limit)
        Otel.SDK.Trace.SpanStorage.insert(%{span | attributes: attributes})
        :ok
    end
  end

  @doc """
  Sets multiple attributes on the span.
  """
  @impl true
  @spec set_attributes(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes :: map() | [{String.t(), term()}]
        ) :: :ok
  def set_attributes(%Otel.API.Trace.SpanContext{span_id: span_id}, new_attributes) do
    new_attributes = to_map(new_attributes)

    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        attributes = merge_attributes(new_attributes, span.attributes, span.span_limits)
        Otel.SDK.Trace.SpanStorage.insert(%{span | attributes: attributes})
        :ok
    end
  end

  @doc """
  Adds an event to the span.
  """
  @impl true
  @spec add_event(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          event :: Otel.API.Trace.Event.t()
        ) :: :ok
  def add_event(
        %Otel.API.Trace.SpanContext{span_id: span_id},
        %Otel.API.Trace.Event{} = event
      ) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        limits = span.span_limits

        if length(span.events) < limits.event_count_limit do
          limited_attributes =
            apply_attribute_limits(
              event.attributes,
              limits.attribute_per_event_limit,
              limits.attribute_value_length_limit
            )

          limited_event = %{event | attributes: limited_attributes}
          Otel.SDK.Trace.SpanStorage.insert(%{span | events: span.events ++ [limited_event]})
        end

        :ok
    end
  end

  @doc """
  Adds a link to another span after creation.
  """
  @impl true
  @spec add_link(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          link :: Otel.API.Trace.Link.t()
        ) :: :ok
  def add_link(
        %Otel.API.Trace.SpanContext{span_id: span_id},
        %Otel.API.Trace.Link{} = link
      ) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        limits = span.span_limits

        if length(span.links) < limits.link_count_limit do
          limited_attributes =
            apply_attribute_limits(
              link.attributes,
              limits.attribute_per_link_limit,
              limits.attribute_value_length_limit
            )

          limited_link = %{link | attributes: limited_attributes}
          Otel.SDK.Trace.SpanStorage.insert(%{span | links: span.links ++ [limited_link]})
        end

        :ok
    end
  end

  @doc """
  Sets the status of the span.

  Status priority: Ok > Error > Unset. Once set to :ok, status is final.
  Setting :unset is always ignored.
  """
  @impl true
  @spec set_status(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          status :: Otel.API.Trace.Status.t()
        ) :: :ok
  def set_status(
        %Otel.API.Trace.SpanContext{span_id: span_id},
        %Otel.API.Trace.Status{} = status
      ) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        updated = apply_set_status(span, status)
        Otel.SDK.Trace.SpanStorage.insert(updated)
        :ok
    end
  end

  @doc """
  Updates the name of the span.
  """
  @impl true
  @spec update_name(span_ctx :: Otel.API.Trace.SpanContext.t(), name :: String.t()) :: :ok
  def update_name(%Otel.API.Trace.SpanContext{span_id: span_id}, name) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        Otel.SDK.Trace.SpanStorage.insert(%{span | name: name})
        :ok
    end
  end

  @doc """
  Ends the span.

  Removes the span from ETS, sets end_time and is_recording=false,
  then calls on_end on all processors.
  """
  @impl true
  @spec end_span(span_ctx :: Otel.API.Trace.SpanContext.t(), timestamp :: non_neg_integer()) ::
          :ok
  def end_span(%Otel.API.Trace.SpanContext{span_id: span_id}, timestamp) do
    case Otel.SDK.Trace.SpanStorage.take(span_id) do
      nil ->
        :ok

      span ->
        end_time = timestamp || System.system_time(:nanosecond)
        ended_span = %{span | end_time: end_time, is_recording: false}
        run_on_end(ended_span, span.processors)
        :ok
    end
  end

  @doc """
  Records an exception as an event on the span.
  """
  @impl true
  @spec record_exception(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          exception :: Exception.t(),
          stacktrace :: list(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) :: :ok
  def record_exception(span_ctx, exception, stacktrace, attributes) do
    exception_attributes =
      Map.merge(
        %{
          "exception.type" => exception_type(exception),
          "exception.message" => Exception.message(exception),
          "exception.stacktrace" => Exception.format_stacktrace(stacktrace)
        },
        attributes
      )

    add_event(span_ctx, Otel.API.Trace.Event.new("exception", exception_attributes))
  end

  # --- Private helpers ---

  @spec new_span_ctx(
          ctx :: Otel.API.Ctx.t(),
          id_generator :: module(),
          opts :: Otel.API.Trace.Span.start_opts()
        ) :: {Otel.API.Trace.SpanContext.t(), Otel.API.Trace.SpanId.t() | nil, boolean() | nil}
  defp new_span_ctx(ctx, id_generator, opts) do
    parent = Otel.API.Trace.current_span(ctx)
    is_root = Keyword.get(opts, :is_root, false)

    if is_root or not Otel.API.Trace.SpanContext.valid?(parent) do
      root_span_ctx(id_generator)
    else
      child_span_ctx(parent, id_generator)
    end
  end

  @spec child_span_ctx(
          parent :: Otel.API.Trace.SpanContext.t(),
          id_generator :: module()
        ) :: {Otel.API.Trace.SpanContext.t(), Otel.API.Trace.SpanId.t(), boolean()}
  defp child_span_ctx(parent, id_generator) do
    span_id = id_generator.generate_span_id()

    {
      %Otel.API.Trace.SpanContext{
        trace_id: parent.trace_id,
        span_id: span_id,
        tracestate: parent.tracestate,
        is_remote: false
      },
      parent.span_id,
      parent.is_remote
    }
  end

  @spec root_span_ctx(id_generator :: module()) ::
          {Otel.API.Trace.SpanContext.t(), nil, nil}
  defp root_span_ctx(id_generator) do
    trace_id = id_generator.generate_trace_id()
    span_id = id_generator.generate_span_id()

    {
      %Otel.API.Trace.SpanContext{
        trace_id: trace_id,
        span_id: span_id,
        is_remote: false
      },
      nil,
      nil
    }
  end

  @spec sample(
          ctx :: Otel.API.Ctx.t(),
          sampler :: Otel.SDK.Trace.Sampler.t(),
          trace_id :: Otel.API.Trace.TraceId.t(),
          links :: [Otel.API.Trace.Link.t()],
          name :: String.t(),
          kind :: Otel.API.Trace.SpanKind.t(),
          attributes :: map()
        ) :: {non_neg_integer(), boolean(), map(), Otel.API.Trace.TraceState.t()}
  defp sample(ctx, sampler, trace_id, links, name, kind, attributes) do
    {decision, new_attributes, tracestate} =
      Otel.SDK.Trace.Sampler.should_sample(
        sampler,
        ctx,
        trace_id,
        links,
        name,
        kind,
        attributes
      )

    case decision do
      :drop -> {0, false, new_attributes, tracestate}
      :record_only -> {0, true, new_attributes, tracestate}
      :record_and_sample -> {1, true, new_attributes, tracestate}
    end
  end

  @spec merge_attributes(
          new_attributes :: map(),
          existing :: map(),
          limits :: Otel.SDK.Trace.SpanLimits.t()
        ) :: map()
  defp merge_attributes(new_attributes, existing, limits) do
    Enum.reduce(new_attributes, existing, fn {key, value}, acc ->
      put_attribute(
        acc,
        key,
        truncate_value(value, limits.attribute_value_length_limit),
        limits.attribute_count_limit
      )
    end)
  end

  @spec put_attribute(
          attributes :: map(),
          key :: String.t(),
          value :: term(),
          count_limit :: pos_integer()
        ) :: map()
  defp put_attribute(attributes, key, value, count_limit) do
    cond do
      Map.has_key?(attributes, key) -> Map.put(attributes, key, value)
      map_size(attributes) < count_limit -> Map.put(attributes, key, value)
      true -> attributes
    end
  end

  @spec apply_set_status(
          span :: t(),
          status :: Otel.API.Trace.Status.t()
        ) :: t()
  defp apply_set_status(span, %Otel.API.Trace.Status{code: :unset}), do: span

  defp apply_set_status(%{status: %Otel.API.Trace.Status{code: :ok}} = span, _status), do: span

  defp apply_set_status(span, %Otel.API.Trace.Status{code: :ok}) do
    %{span | status: %Otel.API.Trace.Status{code: :ok, description: ""}}
  end

  defp apply_set_status(span, %Otel.API.Trace.Status{code: :error, description: description}) do
    %{span | status: %Otel.API.Trace.Status{code: :error, description: description}}
  end

  @spec run_on_end(
          span :: t(),
          processors :: [{module(), term()}]
        ) :: :ok
  defp run_on_end(span, processors) do
    Enum.each(processors, fn {processor, processor_config} ->
      processor.on_end(span, processor_config)
    end)
  end

  @spec apply_attribute_limits(
          attributes :: map(),
          count_limit :: pos_integer(),
          value_length_limit :: pos_integer() | :infinity
        ) :: map()
  defp apply_attribute_limits(attributes, count_limit, value_length_limit) do
    attributes
    |> Enum.take(count_limit)
    |> Enum.map(fn {key, value} ->
      {key, truncate_value(value, value_length_limit)}
    end)
    |> Map.new()
  end

  @spec truncate_value(value :: term(), limit :: pos_integer() | :infinity) :: term()
  defp truncate_value(value, :infinity), do: value

  defp truncate_value(value, limit) when is_binary(value) do
    if String.length(value) > limit, do: String.slice(value, 0, limit), else: value
  end

  defp truncate_value(value, limit) when is_list(value) do
    Enum.map(value, &truncate_value(&1, limit))
  end

  defp truncate_value(value, _limit), do: value

  @spec to_map(attributes :: map() | [{String.t(), term()}]) :: map()
  defp to_map(attributes) when is_map(attributes), do: attributes
  defp to_map(attributes) when is_list(attributes), do: Map.new(attributes)

  @spec exception_type(exception :: Exception.t()) :: String.t()
  defp exception_type(exception) do
    exception.__struct__ |> Atom.to_string() |> String.trim_leading("Elixir.")
  end
end
