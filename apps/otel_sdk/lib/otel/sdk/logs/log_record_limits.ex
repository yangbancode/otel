defmodule Otel.SDK.Logs.LogRecordLimits do
  @moduledoc """
  Configurable limits for LogRecord data.

  Prevents unbounded growth of log record attributes.
  Excess attributes are silently discarded and string values
  exceeding the length limit are truncated. A log message
  SHOULD be emitted at most once per LogRecord when items
  are discarded.
  """

  require Logger

  @type t :: %__MODULE__{
          attribute_count_limit: non_neg_integer(),
          attribute_value_length_limit: non_neg_integer() | :infinity
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
    {truncated, truncated?} = truncate_values(attributes, limits.attribute_value_length_limit)
    count = map_size(truncated)

    {limited, dropped} =
      if count > limits.attribute_count_limit do
        kept =
          truncated
          |> Enum.take(limits.attribute_count_limit)
          |> Map.new()

        {kept, count - limits.attribute_count_limit}
      else
        {truncated, 0}
      end

    log_limits_applied(dropped, truncated?)

    {limited, dropped}
  end

  @spec truncate_values(attributes :: map(), limit :: non_neg_integer() | :infinity) ::
          {map(), boolean()}
  defp truncate_values(attributes, :infinity), do: {attributes, false}

  defp truncate_values(attributes, limit) do
    Enum.reduce(attributes, {%{}, false}, fn {key, value}, {acc, any?} ->
      {new_value, truncated?} = truncate_value(value, limit)
      {Map.put(acc, key, new_value), any? or truncated?}
    end)
  end

  @spec truncate_value(value :: term(), limit :: non_neg_integer()) :: {term(), boolean()}
  defp truncate_value({:bytes, bin}, limit) when is_binary(bin) do
    if byte_size(bin) > limit do
      {{:bytes, binary_part(bin, 0, limit)}, true}
    else
      {{:bytes, bin}, false}
    end
  end

  defp truncate_value(value, limit) when is_binary(value) do
    if String.length(value) > limit do
      {String.slice(value, 0, limit), true}
    else
      {value, false}
    end
  end

  defp truncate_value(value, limit) when is_list(value) do
    Enum.map_reduce(value, false, fn elem, any? ->
      {new_elem, truncated?} = truncate_value(elem, limit)
      {new_elem, any? or truncated?}
    end)
  end

  defp truncate_value(value, _limit), do: {value, false}

  # Spec `logs/sdk.md` L345-348: SHOULD emit a message when
  # attributes are discarded; the message MUST be printed at
  # most once per LogRecord. Once-per-LogRecord is satisfied
  # structurally — `apply/2` is invoked exactly once per
  # LogRecord by `Otel.SDK.Logs.Logger`. Common spec
  # `common/README.md` L284-286 broadens this to "truncated
  # or discarded", so we emit on either condition.
  @spec log_limits_applied(dropped :: non_neg_integer(), truncated? :: boolean()) :: :ok
  defp log_limits_applied(0, false), do: :ok

  defp log_limits_applied(dropped, truncated?) do
    parts =
      [
        dropped > 0 && "dropped #{dropped} attribute(s)",
        truncated? && "truncated value(s) exceeding length limit"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(", ")

    Logger.warning("LogRecord limits applied: #{parts}")
    :ok
  end
end
