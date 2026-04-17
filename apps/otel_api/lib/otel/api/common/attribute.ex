defmodule Otel.API.Common.Attribute do
  @moduledoc """
  Key-value pair used across all OpenTelemetry signals.

  An Attribute pairs a non-empty UTF-8 string key with an
  `Otel.API.Common.AnyValue` value. Collections of attributes are
  represented as `[t()]`; duplicate-key handling, ordering, and
  cardinality limits are the caller's responsibility and enforced
  by the SDK, not at the API level.
  """

  @type t :: %__MODULE__{
          key: String.t(),
          value: Otel.API.Common.AnyValue.t()
        }

  defstruct [:key, :value]

  @doc """
  Creates a new Attribute. `key` must be a non-empty UTF-8 string;
  `value` must be an `%Otel.API.Common.AnyValue{}` struct.
  """
  @spec new(key :: String.t(), value :: Otel.API.Common.AnyValue.t()) :: t()
  def new(key, %Otel.API.Common.AnyValue{} = value) when is_binary(key) do
    (key != "" and String.valid?(key)) ||
      raise ArgumentError, "Attribute key must be a non-empty UTF-8 string"

    %__MODULE__{key: key, value: value}
  end

  @doc """
  Returns `true` if the term is a well-formed Attribute struct.
  """
  @spec valid?(v :: term()) :: boolean()
  def valid?(%__MODULE__{key: key, value: %Otel.API.Common.AnyValue{} = value}) do
    is_binary(key) and key != "" and String.valid?(key) and
      Otel.API.Common.AnyValue.valid?(value)
  end

  def valid?(_), do: false
end
