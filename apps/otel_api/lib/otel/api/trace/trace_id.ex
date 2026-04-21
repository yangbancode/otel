defmodule Otel.API.Trace.TraceId do
  @moduledoc """
  Opaque 128-bit trace identifier.

  The OpenTelemetry spec defines a valid `TraceId` as a 16-byte array with at
  least one non-zero byte. On the BEAM we store it as a non-negative integer
  in the range `0..2^128 - 1`, but expose it through `@opaque` so Dialyzer
  distinguishes it from unrelated integers (including `Otel.API.Trace.SpanId`).

  ## Construction

  Build a `t()` with one of:

  - `new/1` — from a non-negative integer
  - `from_hex/1` — from a 32-character lowercase hex string
  - `from_bytes/1` — from a 16-byte binary
  - `invalid/0` — the all-zero sentinel (`IsValid` → `false`)

  ## Conversion

  - `to_hex/1` returns a 32-character lowercase hex string
  - `to_bytes/1` returns a 16-byte binary
  - `valid?/1` returns `true` iff the trace id has at least one non-zero byte
  """

  @max_value 0xFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF
  @hex_length 32

  @typedoc "A 128-bit trace identifier."
  @opaque t :: 0..0xFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF

  @doc """
  Wraps a non-negative integer as a `t()`.

  Raises `FunctionClauseError` if the integer is outside the 128-bit range.
  """
  @spec new(integer :: non_neg_integer()) :: t()
  def new(integer) when is_integer(integer) and integer >= 0 and integer <= @max_value do
    integer
  end

  @doc """
  Returns the all-zero invalid trace id sentinel.
  """
  @spec invalid() :: t()
  def invalid, do: 0

  @doc """
  Escape hatch returning the underlying non-negative integer.

  Exposed so samplers and other SDK components can perform bit arithmetic on
  the trace id (e.g., `TraceIdRatioBased` takes the lower 64 bits as a
  probability hash). Callers outside the SDK should prefer `to_hex/1` or
  `to_bytes/1`.
  """
  @spec to_integer(trace_id :: t()) :: non_neg_integer()
  def to_integer(trace_id)
      when is_integer(trace_id) and trace_id >= 0 and trace_id <= @max_value,
      do: trace_id

  @doc """
  Returns `true` if the trace id has at least one non-zero byte.

  Per spec, the all-zero value is explicitly invalid.
  """
  @spec valid?(trace_id :: t()) :: boolean()
  def valid?(0), do: false

  def valid?(trace_id)
      when is_integer(trace_id) and trace_id > 0 and trace_id <= @max_value,
      do: true

  @doc """
  Returns the trace id as a 32-character lowercase hex string, zero-padded.
  """
  @spec to_hex(trace_id :: t()) :: <<_::256>>
  def to_hex(trace_id) when is_integer(trace_id) and trace_id >= 0 and trace_id <= @max_value do
    trace_id
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(@hex_length, "0")
  end

  @doc """
  Returns the trace id as a 16-byte big-endian binary.
  """
  @spec to_bytes(trace_id :: t()) :: <<_::128>>
  def to_bytes(trace_id) when is_integer(trace_id) and trace_id >= 0 and trace_id <= @max_value do
    <<trace_id::unsigned-integer-size(128)>>
  end

  @doc """
  Parses a 32-character lowercase hex string into a `t()`.
  """
  @spec from_hex(hex :: <<_::256>>) :: t()
  def from_hex(hex) when is_binary(hex) and byte_size(hex) == @hex_length do
    {integer, ""} = Integer.parse(hex, 16)
    integer
  end

  @doc """
  Parses a 16-byte binary into a `t()`.
  """
  @spec from_bytes(bytes :: <<_::128>>) :: t()
  def from_bytes(<<trace_id::unsigned-integer-size(128)>>) do
    trace_id
  end
end
