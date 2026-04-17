defmodule Otel.API.Trace.SpanId do
  @moduledoc """
  Opaque 8-byte span identifier.

  Stored as a byte array matching the OpenTelemetry specification
  (`trace/api.md` §234-235). The all-zero value
  (`<<0::64>>`) is the invalid sentinel.
  """

  @type t :: %__MODULE__{bytes: <<_::64>>}

  defstruct [:bytes]

  @invalid <<0::64>>

  @doc """
  Wraps an 8-byte binary as a SpanId.
  """
  @spec new(bytes :: <<_::64>>) :: t()
  def new(<<_::64>> = bytes), do: %__MODULE__{bytes: bytes}

  @doc """
  Parses a 16-character lowercase-or-uppercase hex string into a SpanId.
  """
  @spec from_hex(hex :: <<_::128>>) :: t()
  def from_hex(<<_::128>> = hex), do: %__MODULE__{bytes: Base.decode16!(hex, case: :mixed)}

  @doc """
  Returns the 8-byte binary representation.
  """
  @spec to_bytes(span_id :: t()) :: <<_::64>>
  def to_bytes(%__MODULE__{bytes: bytes}), do: bytes

  @doc """
  Returns the 16-character lowercase hex representation.
  """
  @spec to_hex(span_id :: t()) :: <<_::128>>
  def to_hex(%__MODULE__{bytes: bytes}), do: Base.encode16(bytes, case: :lower)

  @doc """
  Returns the invalid SpanId (all-zero bytes).
  """
  @spec invalid() :: t()
  def invalid, do: %__MODULE__{bytes: @invalid}

  @doc """
  Returns `true` if the SpanId has at least one non-zero byte.
  """
  @spec valid?(span_id :: t()) :: boolean()
  def valid?(%__MODULE__{bytes: @invalid}), do: false
  def valid?(%__MODULE__{bytes: <<_::64>>}), do: true
end
