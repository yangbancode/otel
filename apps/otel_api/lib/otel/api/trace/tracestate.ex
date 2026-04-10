defmodule Otel.API.Trace.TraceState do
  @moduledoc """
  W3C Trace Context TraceState.

  An immutable ordered list of vendor-specific key/value pairs
  propagated across tracing systems. Keys and values are validated
  against the W3C Trace Context specification.
  """

  @type t :: %__MODULE__{members: [{String.t(), String.t()}]}

  defstruct members: []

  @max_members 32

  @key_pattern ~r/^(([a-z][_0-9a-z\-*\/]{0,255})|([a-z0-9][_0-9a-z\-*\/]{0,240}@[a-z][_0-9a-z\-*\/]{0,13}))$/
  @value_pattern ~r/^([\x20-\x2b\x2d-\x3c\x3e-\x7e]{0,255}[\x21-\x2b\x2d-\x3c\x3e-\x7e])$/

  @doc """
  Creates an empty TraceState.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Creates a TraceState from a list of `{key, value}` pairs.

  Invalid pairs are silently dropped.
  """
  @spec new([{String.t(), String.t()}]) :: t()
  def new(list) when is_list(list) do
    members =
      list
      |> Enum.filter(fn {key, value} -> valid_key?(key) and valid_value?(value) end)
      |> Enum.take(@max_members)

    %__MODULE__{members: members}
  end

  @doc """
  Returns the value for `key`, or `""` if not found.
  """
  @spec get(t(), String.t()) :: String.t()
  def get(%__MODULE__{members: members}, key) do
    case List.keyfind(members, key, 0) do
      {_, value} -> value
      nil -> ""
    end
  end

  @doc """
  Adds or updates a key/value pair.

  The pair is moved to the front of the list per W3C spec.
  Returns the TraceState unchanged if key or value is invalid.
  """
  @spec put(t(), String.t(), String.t()) :: t()
  def put(%__MODULE__{members: members} = ts, key, value) do
    if valid_key?(key) and valid_value?(value) do
      new_members = [{key, value} | List.keydelete(members, key, 0)]
      %__MODULE__{ts | members: Enum.take(new_members, @max_members)}
    else
      ts
    end
  end

  @doc """
  Removes the entry for `key`.
  """
  @spec delete(t(), String.t()) :: t()
  def delete(%__MODULE__{members: members} = ts, key) do
    %__MODULE__{ts | members: List.keydelete(members, key, 0)}
  end

  @doc """
  Encodes the TraceState to a W3C `tracestate` header value.

  Returns `""` for an empty TraceState.
  """
  @spec encode(t()) :: String.t()
  def encode(%__MODULE__{members: []}), do: ""

  def encode(%__MODULE__{members: members}) do
    Enum.map_join(members, ",", fn {key, value} -> "#{key}=#{value}" end)
  end

  @doc """
  Decodes a W3C `tracestate` header value into a TraceState.

  Invalid entries cause the entire header to be rejected (returns
  empty TraceState), per W3C spec.
  """
  @spec decode(String.t()) :: t()
  def decode(header) when is_binary(header) do
    pairs =
      header
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> parse_pairs()

    case pairs do
      :error -> new()
      members -> %__MODULE__{members: Enum.take(members, @max_members)}
    end
  end

  defp parse_pairs(raw_pairs) do
    Enum.reduce_while(raw_pairs, [], fn pair, acc ->
      case String.split(pair, "=", parts: 2) do
        [key, value] when value != "" ->
          if valid_key?(key) and valid_value?(value) do
            {:cont, List.keystore(acc, key, 0, {key, value})}
          else
            {:halt, :error}
          end

        _ ->
          {:halt, :error}
      end
    end)
  end

  defp valid_key?(key) when is_binary(key), do: Regex.match?(@key_pattern, key)
  defp valid_key?(_), do: false

  defp valid_value?(value) when is_binary(value), do: Regex.match?(@value_pattern, value)
  defp valid_value?(_), do: false
end
