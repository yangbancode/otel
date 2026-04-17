defmodule Otel.API.Common.AnyValue do
  @moduledoc """
  Tagged union value type used across all OpenTelemetry signals.

  Represents any value carried by the OTel data model — log record
  bodies, attribute values, and nested collections. Mirrors the
  `AnyValue` OTLP proto message.

  Variants: `:string`, `:bool`, `:int`, `:double`, `:bytes`, `:array`,
  `:kvlist`, `:empty`. Each variant is produced by its named
  constructor; there is no smart constructor that infers a variant
  from a native value.
  """

  @type tag :: :string | :bool | :int | :double | :bytes | :array | :kvlist | :empty

  @type t :: %__MODULE__{
          type: tag(),
          value: term()
        }

  defstruct [:type, :value]

  @int64_max 0x7FFF_FFFF_FFFF_FFFF
  @int64_min -0x8000_0000_0000_0000

  @doc """
  Produces a string-valued AnyValue. Input must be valid UTF-8.
  """
  @spec string(v :: String.t()) :: t()
  def string(v) when is_binary(v) do
    String.valid?(v) ||
      raise ArgumentError,
            "AnyValue.string/1 requires valid UTF-8; use bytes/1 for arbitrary binary"

    %__MODULE__{type: :string, value: v}
  end

  @doc """
  Produces a boolean-valued AnyValue.
  """
  @spec bool(v :: boolean()) :: t()
  def bool(v) when is_boolean(v), do: %__MODULE__{type: :bool, value: v}

  @doc """
  Produces a signed 64-bit integer AnyValue. Rejects values outside int64 range.
  """
  @spec int(v :: integer()) :: t()
  def int(v) when is_integer(v) and v >= @int64_min and v <= @int64_max do
    %__MODULE__{type: :int, value: v}
  end

  @doc """
  Produces an IEEE 754 double AnyValue.
  """
  @spec double(v :: float()) :: t()
  def double(v) when is_float(v), do: %__MODULE__{type: :double, value: v}

  @doc """
  Produces a byte-array AnyValue. Accepts any binary, including non-UTF-8.
  """
  @spec bytes(v :: binary()) :: t()
  def bytes(v) when is_binary(v), do: %__MODULE__{type: :bytes, value: v}

  @doc """
  Produces an array AnyValue. Every element must already be an AnyValue struct.
  """
  @spec array(vs :: [t()]) :: t()
  def array(vs) when is_list(vs) do
    Enum.all?(vs, &match?(%__MODULE__{}, &1)) ||
      raise ArgumentError, "AnyValue.array/1 elements must be %AnyValue{} structs"

    %__MODULE__{type: :array, value: vs}
  end

  @doc """
  Produces a kvlist AnyValue from a `%{String.t() => t()}` map.
  Keys must be non-empty UTF-8 strings; values must be AnyValue structs.
  """
  @spec kvlist(m :: %{String.t() => t()}) :: t()
  def kvlist(m) when is_map(m) do
    Enum.all?(m, fn {k, v} ->
      is_binary(k) and k != "" and String.valid?(k) and match?(%__MODULE__{}, v)
    end) ||
      raise ArgumentError,
            "AnyValue.kvlist/1 requires non-empty string keys and %AnyValue{} values"

    %__MODULE__{type: :kvlist, value: m}
  end

  @doc """
  Produces the empty/null AnyValue.
  """
  @spec empty() :: t()
  def empty, do: %__MODULE__{type: :empty, value: nil}

  @doc """
  Returns `true` if the term is an AnyValue struct with a recognized tag.
  """
  @spec valid?(v :: term()) :: boolean()
  def valid?(%__MODULE__{type: type})
      when type in [:string, :bool, :int, :double, :bytes, :array, :kvlist, :empty],
      do: true

  def valid?(_), do: false
end
