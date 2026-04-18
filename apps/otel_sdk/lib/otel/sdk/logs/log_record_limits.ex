defmodule Otel.SDK.Logs.LogRecordLimits do
  @moduledoc """
  Configurable limits for LogRecord data.

  Prevents unbounded growth of log record attributes.
  Excess attributes are silently discarded and string values
  exceeding the length limit are truncated. A log message
  SHOULD be emitted at most once per LogRecord when items
  are discarded.
  """

  @type t :: %__MODULE__{
          attribute_count_limit: pos_integer(),
          attribute_value_length_limit: pos_integer() | :infinity
        }

  defstruct attribute_count_limit: 128,
            attribute_value_length_limit: :infinity

  @doc """
  Applies attribute limits to a map of attributes.

  Truncates string values exceeding the length limit and silently
  discards attributes beyond the count limit.
  """
  @spec apply(attributes :: map(), limits :: t()) :: {map(), non_neg_integer()}
  def apply(attributes, %__MODULE__{} = limits) do
    truncated = truncate_values(attributes, limits.attribute_value_length_limit)
    count = map_size(truncated)

    if count > limits.attribute_count_limit do
      limited =
        truncated
        |> Enum.take(limits.attribute_count_limit)
        |> Map.new()

      {limited, count - limits.attribute_count_limit}
    else
      {truncated, 0}
    end
  end

  @spec truncate_values(attributes :: map(), limit :: pos_integer() | :infinity) :: map()
  defp truncate_values(attributes, :infinity), do: attributes

  defp truncate_values(attributes, limit) do
    Map.new(attributes, fn {key, value} ->
      {key, truncate_value(value, limit)}
    end)
  end

  @spec truncate_value(value :: term(), limit :: pos_integer()) :: term()
  defp truncate_value(value, limit) when is_binary(value) do
    if String.length(value) > limit, do: String.slice(value, 0, limit), else: value
  end

  defp truncate_value(value, limit) when is_list(value) do
    Enum.map(value, &truncate_value(&1, limit))
  end

  defp truncate_value(value, _limit), do: value
end
