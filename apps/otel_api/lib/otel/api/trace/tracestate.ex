defmodule Otel.API.Trace.TraceState do
  @moduledoc """
  W3C Trace Context TraceState.

  An immutable ordered list of vendor-specific key/value pairs
  propagated across tracing systems.
  """

  @type t :: %__MODULE__{members: [{String.t(), String.t()}]}

  defstruct members: []

  @max_members 32

  @doc """
  Creates an empty TraceState.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Creates a TraceState from a list of `{key, value}` pairs.
  """
  @spec new(list :: [{String.t(), String.t()}]) :: t()
  def new(list) when is_list(list) do
    %__MODULE__{members: Enum.take(list, @max_members)}
  end

  @doc """
  Returns the number of entries in the TraceState.
  """
  @spec size(trace_state :: t()) :: non_neg_integer()
  def size(%__MODULE__{members: members}), do: length(members)

  @doc """
  Returns the value for `key`, or `""` if not found.
  """
  @spec get(trace_state :: t(), key :: String.t()) :: String.t()
  def get(%__MODULE__{members: members}, key) do
    case List.keyfind(members, key, 0) do
      {_, value} -> value
      nil -> ""
    end
  end

  @doc """
  Adds a new key/value pair to the front of the list.

  If the TraceState is already at the max member limit, returns
  the TraceState unchanged.
  """
  @spec add(trace_state :: t(), key :: String.t(), value :: String.t()) :: t()
  def add(%__MODULE__{members: members} = ts, key, value) do
    if length(members) < @max_members do
      %__MODULE__{ts | members: [{key, value} | members]}
    else
      ts
    end
  end

  @doc """
  Updates an existing key's value and moves it to the front.
  """
  @spec update(trace_state :: t(), key :: String.t(), value :: String.t()) :: t()
  def update(%__MODULE__{members: members} = ts, key, value) do
    %__MODULE__{ts | members: [{key, value} | List.keydelete(members, key, 0)]}
  end

  @doc """
  Removes the entry for `key`.
  """
  @spec delete(trace_state :: t(), key :: String.t()) :: t()
  def delete(%__MODULE__{members: members} = ts, key) do
    %__MODULE__{ts | members: List.keydelete(members, key, 0)}
  end

  @doc """
  Encodes the TraceState to a W3C `tracestate` header value.

  Returns `""` for an empty TraceState.
  """
  @spec encode(trace_state :: t()) :: String.t()
  def encode(%__MODULE__{members: []}), do: ""

  def encode(%__MODULE__{members: members}) do
    Enum.map_join(members, ",", fn {key, value} -> "#{key}=#{value}" end)
  end

  @doc """
  Decodes a W3C `tracestate` header value into a TraceState.
  """
  @spec decode(header :: String.t()) :: t()
  def decode(header) when is_binary(header) do
    members =
      header
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&parse_pair/1)
      |> Enum.reduce([], fn {key, value}, acc ->
        List.keystore(acc, key, 0, {key, value})
      end)
      |> Enum.take(@max_members)

    %__MODULE__{members: members}
  end

  @spec parse_pair(pair :: String.t()) :: {String.t(), String.t()}
  defp parse_pair(pair) do
    [key, value] = String.split(pair, "=", parts: 2)
    {key, value}
  end
end
