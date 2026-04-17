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
  Applies attribute limits to a list of `Otel.API.Common.Attribute.t()`.

  Truncates string/bytes values exceeding the length limit (recursing
  into arrays) and discards attributes beyond the count limit. Logs a
  warning at most once per call when attributes are discarded.
  """
  @spec apply(
          attributes :: [Otel.API.Common.Attribute.t()],
          limits :: t()
        ) :: {[Otel.API.Common.Attribute.t()], non_neg_integer()}
  def apply(attributes, %__MODULE__{} = limits) when is_list(attributes) do
    truncated = truncate_attributes(attributes, limits.attribute_value_length_limit)
    count = length(truncated)

    if count > limits.attribute_count_limit do
      limited = Enum.take(truncated, limits.attribute_count_limit)
      dropped = count - limits.attribute_count_limit

      :logger.warning(
        "LogRecord attributes exceeded limit of #{limits.attribute_count_limit}, " <>
          "dropped #{dropped} attribute(s)",
        %{domain: [:otel, :logs]}
      )

      {limited, dropped}
    else
      {truncated, 0}
    end
  end

  @spec truncate_attributes(
          attributes :: [Otel.API.Common.Attribute.t()],
          limit :: pos_integer() | :infinity
        ) :: [Otel.API.Common.Attribute.t()]
  defp truncate_attributes(attributes, :infinity), do: attributes

  defp truncate_attributes(attributes, limit) do
    Enum.map(attributes, fn %Otel.API.Common.Attribute{key: key, value: value} ->
      %Otel.API.Common.Attribute{key: key, value: truncate_any_value(value, limit)}
    end)
  end

  @spec truncate_any_value(
          value :: Otel.API.Common.AnyValue.t(),
          limit :: pos_integer()
        ) :: Otel.API.Common.AnyValue.t()
  defp truncate_any_value(%Otel.API.Common.AnyValue{type: :string, value: v} = av, limit) do
    if String.length(v) > limit do
      %Otel.API.Common.AnyValue{av | value: String.slice(v, 0, limit)}
    else
      av
    end
  end

  defp truncate_any_value(%Otel.API.Common.AnyValue{type: :bytes, value: v} = av, limit) do
    if byte_size(v) > limit do
      %Otel.API.Common.AnyValue{av | value: binary_part(v, 0, limit)}
    else
      av
    end
  end

  defp truncate_any_value(%Otel.API.Common.AnyValue{type: :array, value: vs} = av, limit) do
    %Otel.API.Common.AnyValue{av | value: Enum.map(vs, &truncate_any_value(&1, limit))}
  end

  defp truncate_any_value(%Otel.API.Common.AnyValue{} = av, _limit), do: av
end
