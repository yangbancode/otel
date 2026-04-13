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
          key :: String.t() | atom(),
          value :: term()
        ) :: :ok
  def set_attribute(%Otel.API.Trace.SpanContext{span_id: span_id}, key, value) do
    case Otel.SDK.Trace.SpanStorage.get(span_id) do
      nil ->
        :ok

      span ->
        limits = span.span_limits
        value = truncate_value(value, limits.attribute_value_length_limit)

        attributes =
          cond do
            Map.has_key?(span.attributes, key) ->
              Map.put(span.attributes, key, value)

            map_size(span.attributes) < limits.attribute_count_limit ->
              Map.put(span.attributes, key, value)

            true ->
              span.attributes
          end

        Otel.SDK.Trace.SpanStorage.insert(%{span | attributes: attributes})
        :ok
    end
  end

  @doc """
  Sets multiple attributes on the span.
  """
  @spec set_attributes(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          attributes :: map() | [{String.t() | atom(), term()}]
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
  @spec add_event(
          span_ctx :: Otel.API.Trace.SpanContext.t(),
          name :: String.t() | atom(),
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
          attributes = Keyword.get(opts, :attributes, %{})

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
          attributes :: map()
        ) :: :ok
  def add_link(%Otel.API.Trace.SpanContext{span_id: span_id}, linked_ctx, attributes) do
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

  Status priority: Ok > Error > Unset. Once set to :ok, status is final.
  Setting :unset is always ignored.
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

  Removes the span from ETS, sets end_time and is_recording=false,
  then calls on_end on all processors.
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
          attributes :: map()
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

    add_event(span_ctx, "exception", attributes: exception_attributes)
  end

  # --- Private helpers ---

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
          key :: String.t() | atom(),
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

  defp truncate_value(value, limit) when is_binary(value) and byte_size(value) > limit do
    String.slice(value, 0, limit)
  end

  defp truncate_value(value, limit) when is_list(value) do
    Enum.map(value, &truncate_value(&1, limit))
  end

  defp truncate_value(value, _limit), do: value

  @spec to_map(attributes :: map() | [{String.t() | atom(), term()}]) :: map()
  defp to_map(attributes) when is_map(attributes), do: attributes
  defp to_map(attributes) when is_list(attributes), do: Map.new(attributes)

  @spec exception_type(exception :: Exception.t()) :: String.t()
  defp exception_type(exception) do
    exception.__struct__ |> Atom.to_string() |> String.trim_leading("Elixir.")
  end
end
