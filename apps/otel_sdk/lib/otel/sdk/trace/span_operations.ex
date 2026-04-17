defmodule Otel.SDK.Trace.SpanOperations do
  @moduledoc """
  SDK implementation of span operations.

  Reads and writes span data in ETS via `SpanStorage`. All operations
  are no-ops if the span is not found in ETS (already ended or dropped).
  Registered as the global span module on SDK application start.
  """

  @doc """
  Returns whether the span is currently recording.
  """
  @spec recording?(span_ctx :: Otel.API.Trace.SpanContext.t()) :: boolean()
  def recording?(%Otel.API.Trace.SpanContext{span_id: span_id}) do
    Otel.SDK.Trace.SpanStorage.get(span_id) != nil
  end

  @doc """
  Sets a single attribute on the span.
  """
  @spec set_attribute(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          key :: String.t(),
          value :: Otel.API.Common.AnyValue.t()
        ) :: :ok
  def set_attribute(
        %Otel.API.Trace.SpanContext{span_id: span_id},
        key,
        %Otel.API.Common.AnyValue{} = value
      )
      when is_binary(key) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        limits = span.span_limits
        truncated = truncate_any_value(value, limits.attribute_value_length_limit)
        new_attr = Otel.API.Common.Attribute.new(key, truncated)
        attributes = put_attribute(span.attributes, new_attr, limits.attribute_count_limit)
        Otel.SDK.Trace.SpanStorage.insert(%{span | attributes: attributes})
        :ok
    end
  end

  @doc """
  Sets multiple attributes on the span.
  """
  @spec set_attributes(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes :: [Otel.API.Common.Attribute.t()]
        ) :: :ok
  def set_attributes(%Otel.API.Trace.SpanContext{span_id: span_id}, new_attributes)
      when is_list(new_attributes) do
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
  @spec add_event(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: :ok
  def add_event(%Otel.API.Trace.SpanContext{span_id: span_id}, name, opts) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        limits = span.span_limits

        if length(span.events) < limits.event_count_limit do
          time = Keyword.get(opts, :time, System.system_time(:nanosecond))
          attributes = Keyword.get(opts, :attributes, [])

          limited_attributes =
            apply_attribute_limits(
              attributes,
              limits.attribute_per_event_limit,
              limits.attribute_value_length_limit
            )

          event = %{name: name, time: time, attributes: limited_attributes}
          Otel.SDK.Trace.SpanStorage.insert(%{span | events: span.events ++ [event]})
        end

        :ok
    end
  end

  @doc """
  Adds a link to another span after creation.
  """
  @spec add_link(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          linked_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes :: [Otel.API.Common.Attribute.t()]
        ) :: :ok
  def add_link(%Otel.API.Trace.SpanContext{span_id: span_id}, linked_ctx, attributes)
      when is_list(attributes) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        limits = span.span_limits

        if length(span.links) < limits.link_count_limit do
          limited_attributes =
            apply_attribute_limits(
              attributes,
              limits.attribute_per_link_limit,
              limits.attribute_value_length_limit
            )

          link = {linked_ctx, limited_attributes}
          Otel.SDK.Trace.SpanStorage.insert(%{span | links: span.links ++ [link]})
        end

        :ok
    end
  end

  @doc """
  Sets the status of the span.
  """
  @spec set_status(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          code :: Otel.API.Trace.Span.status_code(),
          description :: String.t()
        ) :: :ok
  def set_status(%Otel.API.Trace.SpanContext{span_id: span_id}, code, description) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        updated = apply_set_status(span, code, description)
        Otel.SDK.Trace.SpanStorage.insert(updated)
        :ok
    end
  end

  @doc """
  Updates the name of the span.
  """
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
  """
  @spec end_span(span_ctx :: Otel.API.Trace.SpanContext.t(), timestamp :: integer() | nil) :: :ok
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
  @spec record_exception(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          exception :: Exception.t(),
          stacktrace :: list(),
          attributes :: [Otel.API.Common.Attribute.t()]
        ) :: :ok
  def record_exception(span_ctx, exception, stacktrace, attributes) when is_list(attributes) do
    exception_attrs = [
      Otel.API.Common.Attribute.new(
        "exception.type",
        Otel.API.Common.AnyValue.string(exception_type(exception))
      ),
      Otel.API.Common.Attribute.new(
        "exception.message",
        Otel.API.Common.AnyValue.string(Exception.message(exception))
      ),
      Otel.API.Common.Attribute.new(
        "exception.stacktrace",
        Otel.API.Common.AnyValue.string(Exception.format_stacktrace(stacktrace))
      )
    ]

    merged = merge_attribute_lists(exception_attrs, attributes)
    add_event(span_ctx, "exception", attributes: merged)
  end

  # --- Private helpers ---

  @spec merge_attributes(
          new_attributes :: [Otel.API.Common.Attribute.t()],
          existing :: [Otel.API.Common.Attribute.t()],
          limits :: Otel.SDK.Trace.SpanLimits.t()
        ) :: [Otel.API.Common.Attribute.t()]
  defp merge_attributes(new_attributes, existing, limits) do
    Enum.reduce(new_attributes, existing, fn %Otel.API.Common.Attribute{} = attr, acc ->
      truncated_value =
        truncate_any_value(attr.value, limits.attribute_value_length_limit)

      put_attribute(
        acc,
        %{attr | value: truncated_value},
        limits.attribute_count_limit
      )
    end)
  end

  @spec put_attribute(
          attributes :: [Otel.API.Common.Attribute.t()],
          attribute :: Otel.API.Common.Attribute.t(),
          count_limit :: pos_integer()
        ) :: [Otel.API.Common.Attribute.t()]
  defp put_attribute(attributes, %Otel.API.Common.Attribute{key: key} = attr, count_limit) do
    {existing, others} = Enum.split_with(attributes, &(&1.key == key))

    cond do
      existing != [] -> others ++ [attr]
      length(attributes) < count_limit -> attributes ++ [attr]
      true -> attributes
    end
  end

  @spec merge_attribute_lists(
          base :: [Otel.API.Common.Attribute.t()],
          override :: [Otel.API.Common.Attribute.t()]
        ) :: [Otel.API.Common.Attribute.t()]
  defp merge_attribute_lists(base, override) do
    override_keys = MapSet.new(override, & &1.key)
    Enum.reject(base, &MapSet.member?(override_keys, &1.key)) ++ override
  end

  @spec apply_set_status(
          span :: Otel.SDK.Trace.Span.t(),
          code :: Otel.API.Trace.Span.status_code(),
          description :: String.t()
        ) :: Otel.SDK.Trace.Span.t()
  defp apply_set_status(span, :unset, _description), do: span
  defp apply_set_status(%{status: {:ok, _}} = span, _code, _description), do: span
  defp apply_set_status(span, :ok, _description), do: %{span | status: {:ok, ""}}
  defp apply_set_status(span, :error, description), do: %{span | status: {:error, description}}

  @spec run_on_end(
          span :: Otel.SDK.Trace.Span.t(),
          processors :: [{module(), term()}]
        ) :: :ok
  defp run_on_end(span, processors) do
    Enum.each(processors, fn {processor, processor_config} ->
      processor.on_end(span, processor_config)
    end)
  end

  @spec apply_attribute_limits(
          attributes :: [Otel.API.Common.Attribute.t()],
          count_limit :: pos_integer(),
          value_length_limit :: pos_integer() | :infinity
        ) :: [Otel.API.Common.Attribute.t()]
  defp apply_attribute_limits(attributes, count_limit, value_length_limit) do
    attributes
    |> Enum.take(count_limit)
    |> Enum.map(fn %Otel.API.Common.Attribute{value: value} = attr ->
      %{attr | value: truncate_any_value(value, value_length_limit)}
    end)
  end

  @spec truncate_any_value(
          value :: Otel.API.Common.AnyValue.t(),
          limit :: pos_integer() | :infinity
        ) :: Otel.API.Common.AnyValue.t()
  defp truncate_any_value(value, :infinity), do: value

  defp truncate_any_value(%Otel.API.Common.AnyValue{type: :string, value: s} = v, limit)
       when is_integer(limit) do
    if String.length(s) > limit, do: %{v | value: String.slice(s, 0, limit)}, else: v
  end

  defp truncate_any_value(%Otel.API.Common.AnyValue{type: :bytes, value: b} = v, limit)
       when is_integer(limit) do
    if byte_size(b) > limit, do: %{v | value: binary_part(b, 0, limit)}, else: v
  end

  defp truncate_any_value(%Otel.API.Common.AnyValue{type: :array, value: vs} = v, limit)
       when is_integer(limit) do
    %{v | value: Enum.map(vs, &truncate_any_value(&1, limit))}
  end

  defp truncate_any_value(%Otel.API.Common.AnyValue{} = v, _limit), do: v

  @spec exception_type(exception :: Exception.t()) :: String.t()
  defp exception_type(exception) do
    exception.__struct__ |> Atom.to_string() |> String.trim_leading("Elixir.")
  end
end
