defmodule Otel.API.Trace.TraceId do
  @moduledoc """
  Opaque 16-byte trace identifier.

  Stored as a byte array matching the OpenTelemetry specification
  (`trace/api.md` §231-232). The all-zero value
  (`<<0::128>>`) is the invalid sentinel.
  """

  @type t :: %__MODULE__{bytes: <<_::128>>}

  defstruct [:bytes]

  @invalid <<0::128>>

  @doc """
  Wraps a 16-byte binary as a TraceId.
  """
  @spec new(bytes :: <<_::128>>) :: t()
  def new(<<_::128>> = bytes), do: %__MODULE__{bytes: bytes}

  @doc """
  Parses a 32-character lowercase-or-uppercase hex string into a TraceId.
  """
  @spec from_hex(hex :: <<_::256>>) :: t()
  def from_hex(<<_::256>> = hex), do: %__MODULE__{bytes: Base.decode16!(hex, case: :mixed)}

  @doc """
  Returns the 16-byte binary representation.
  """
  @spec to_bytes(trace_id :: t()) :: <<_::128>>
  def to_bytes(%__MODULE__{bytes: bytes}), do: bytes

  @doc """
  Returns the 32-character lowercase hex representation.
  """
  @spec to_hex(trace_id :: t()) :: <<_::256>>
  def to_hex(%__MODULE__{bytes: bytes}), do: Base.encode16(bytes, case: :lower)

  @doc """
  Returns the invalid TraceId (all-zero bytes).
  """
  @spec invalid() :: t()
  def invalid, do: %__MODULE__{bytes: @invalid}

  @doc """
  Returns `true` if the TraceId has at least one non-zero byte.
  """
  @spec valid?(trace_id :: t()) :: boolean()
  def valid?(%__MODULE__{bytes: @invalid}), do: false
  def valid?(%__MODULE__{bytes: <<_::128>>}), do: true
end
