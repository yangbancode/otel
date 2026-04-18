defmodule Otel.API.Trace.SpanId do
  @moduledoc """
  Opaque 64-bit span identifier.

  The OpenTelemetry spec defines a valid `SpanId` as an 8-byte array with at
  least one non-zero byte. On the BEAM we store it as a non-negative integer
  in the range `0..2^64 - 1`, but expose it through `@opaque` so Dialyzer
  distinguishes it from unrelated integers (including `Otel.API.Trace.TraceId`).

  ## Construction

  Build a `t()` with one of:

  - `new/1` — from a non-negative integer
  - `from_hex/1` — from a 16-character lowercase hex string
  - `from_bytes/1` — from an 8-byte binary
  - `invalid/0` — the all-zero sentinel (`IsValid` → `false`)

  ## Conversion

  - `to_hex/1` returns a 16-character lowercase hex string
  - `to_bytes/1` returns an 8-byte binary
  - `valid?/1` returns `true` iff the span id has at least one non-zero byte
  """

  @max_value 0xFFFFFFFF_FFFFFFFF
  @hex_length 16

  @typedoc "A 64-bit span identifier."
  @opaque t :: 0..0xFFFFFFFF_FFFFFFFF

  @doc """
  Wraps a non-negative integer as a `t()`.

  Raises `FunctionClauseError` if the integer is outside the 64-bit range.
  """
  @spec new(integer :: non_neg_integer()) :: t()
  def new(integer) when is_integer(integer) and integer >= 0 and integer <= @max_value do
    integer
  end

  @doc """
  Returns the all-zero invalid span id sentinel.
  """
  @spec invalid() :: t()
  def invalid, do: 0

  @doc """
  Guard-safe check for the all-zero invalid sentinel.

  Use this in pattern-match guards instead of comparing a `t()` against the
  integer literal `0`, which would break opacity outside this module.
  """
  defguard is_invalid(span_id) when span_id === 0

  @doc """
  Returns `true` if the span id has at least one non-zero byte.

  Per spec, the all-zero value is explicitly invalid.
  """
  @spec valid?(span_id :: t()) :: boolean()
  def valid?(0), do: false

  def valid?(span_id)
      when is_integer(span_id) and span_id > 0 and span_id <= @max_value,
      do: true

  @doc """
  Returns the span id as a 16-character lowercase hex string, zero-padded.
  """
  @spec to_hex(span_id :: t()) :: <<_::128>>
  def to_hex(span_id) when is_integer(span_id) and span_id >= 0 and span_id <= @max_value do
    span_id
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(@hex_length, "0")
  end

  @doc """
  Returns the span id as an 8-byte big-endian binary.
  """
  @spec to_bytes(span_id :: t()) :: <<_::64>>
  def to_bytes(span_id) when is_integer(span_id) and span_id >= 0 and span_id <= @max_value do
    <<span_id::unsigned-integer-size(64)>>
  end

  @doc """
  Parses a 16-character lowercase hex string into a `t()`.

  Returns `{:ok, span_id}` or `:error` on malformed input.
  """
  @spec from_hex(hex :: binary()) :: {:ok, t()} | :error
  def from_hex(hex) when is_binary(hex) and byte_size(hex) == @hex_length do
    case Integer.parse(hex, 16) do
      {integer, ""} when integer >= 0 and integer <= @max_value -> {:ok, integer}
      _ -> :error
    end
  end

  def from_hex(_), do: :error

  @doc """
  Parses an 8-byte binary into a `t()`.

  Returns `{:ok, span_id}` or `:error` on malformed input.
  """
  @spec from_bytes(bytes :: binary()) :: {:ok, t()} | :error
  def from_bytes(<<span_id::unsigned-integer-size(64)>>) do
    {:ok, span_id}
  end

  def from_bytes(_), do: :error
end
