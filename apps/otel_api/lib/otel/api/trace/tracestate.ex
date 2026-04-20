defmodule Otel.API.Trace.TraceState do
  @moduledoc """
  W3C Trace Context TraceState.

  An immutable ordered list of vendor-specific key/value pairs
  propagated across tracing systems.
  """

  @typedoc """
  A W3C TraceState key (spec §3.3.1.1).

  Two valid forms:
  - `simple-key` — lowercase letter followed by up to 255 characters
    from `[a-z0-9_\\-*/]`.
  - `tenant@system` (multi-tenant) — `tenant-id` (lowercase-alphanumeric
    start, up to 241 chars total) + `@` + `system-id` (lowercase-letter
    start, up to 14 chars total).

  Invalid keys are silently dropped by mutating operations and decoders.
  """
  @type key :: String.t()

  @typedoc """
  A W3C TraceState value (spec §3.3.2).

  Printable ASCII (0x20–0x7E) excluding `,` (0x2C) and `=` (0x3D),
  with a maximum of 256 characters and the last character MUST NOT
  be a space. Invalid values are silently dropped by mutating
  operations and decoders.
  """
  @type value :: String.t()

  @type t :: %__MODULE__{members: [{key(), value()}]}

  defstruct members: []

  @max_members 32
  @max_header_bytes 512

  # W3C Trace Context key format (§ 3.3.1.1):
  # simple-key       = lcalpha         0*255(lcalpha / DIGIT / "_" / "-" / "*" / "/")
  # multi-tenant key = tenant-id "@" system-id
  # tenant-id        = (lcalpha / DIGIT) 0*240(lcalpha / DIGIT / "_" / "-" / "*" / "/")
  # system-id        = lcalpha         0*13(lcalpha / DIGIT / "_" / "-" / "*" / "/")
  @key_regex ~r/^([a-z][a-z0-9_\-*\/]{0,255}|[a-z0-9][a-z0-9_\-*\/]{0,240}@[a-z][a-z0-9_\-*\/]{0,13})$/

  # Value format (§ 3.3.2):
  # printable ASCII (0x20-0x7E) excluding "," (0x2C) and "=" (0x3D),
  # max 256 characters, last character MUST NOT be a space (0x20).
  @value_regex ~r/^[\x20-\x2B\x2D-\x3C\x3E-\x7E]{0,255}[\x21-\x2B\x2D-\x3C\x3E-\x7E]$/

  @doc """
  Creates a TraceState from a list of `{key, value}` pairs.

  Invalid entries (per W3C Trace Context § 3.3.2) are dropped. For
  an empty TraceState, use `%#{inspect(__MODULE__)}{}` directly.
  """
  @spec new(list :: [{key(), value()}]) :: t()
  def new(list) when is_list(list) do
    members =
      list
      |> Enum.filter(fn
        {k, v} -> valid_key?(k) and valid_value?(v)
        _ -> false
      end)
      |> Enum.take(@max_members)

    %__MODULE__{members: members}
  end

  @doc """
  Returns the number of entries in the TraceState.
  """
  @spec size(trace_state :: t()) :: non_neg_integer()
  def size(%__MODULE__{members: members}), do: length(members)

  @doc """
  Returns the value for `key`, or `""` if not found.
  """
  @spec get(trace_state :: t(), key :: key()) :: value()
  def get(%__MODULE__{members: members}, key) do
    case List.keyfind(members, key, 0) do
      {_, value} -> value
      nil -> ""
    end
  end

  @doc """
  Adds a new key/value pair to the front of the list.

  Returns the TraceState unchanged when the key or value is invalid
  per W3C Trace Context § 3.3.2, or when the member limit is reached.
  """
  @spec add(trace_state :: t(), key :: key(), value :: value()) :: t()
  def add(%__MODULE__{members: members} = ts, key, value) do
    cond do
      not valid_key?(key) -> ts
      not valid_value?(value) -> ts
      length(members) >= @max_members -> ts
      true -> %__MODULE__{ts | members: [{key, value} | members]}
    end
  end

  @doc """
  Updates an existing key's value and moves it to the front.

  Returns the TraceState unchanged when the key or value is invalid
  per W3C Trace Context § 3.3.2.
  """
  @spec update(trace_state :: t(), key :: key(), value :: value()) :: t()
  def update(%__MODULE__{members: members} = ts, key, value) do
    cond do
      not valid_key?(key) -> ts
      not valid_value?(value) -> ts
      true -> %__MODULE__{ts | members: [{key, value} | List.keydelete(members, key, 0)]}
    end
  end

  @doc """
  Removes the entry for `key`.
  """
  @spec delete(trace_state :: t(), key :: key()) :: t()
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

  Returns an empty TraceState when the header exceeds the 512-byte
  W3C cap (§ 3.3.3). Invalid entries (bad key/value format or missing
  `=`) are dropped.
  """
  @spec decode(header :: String.t()) :: t()
  def decode(header) when is_binary(header) do
    if byte_size(header) > @max_header_bytes do
      %__MODULE__{}
    else
      members =
        header
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.flat_map(&parse_pair/1)
        |> Enum.reduce([], fn {key, value}, acc ->
          List.keystore(acc, key, 0, {key, value})
        end)
        |> Enum.take(@max_members)

      %__MODULE__{members: members}
    end
  end

  @spec parse_pair(pair :: String.t()) :: [{key(), value()}]
  defp parse_pair(pair) do
    case String.split(pair, "=", parts: 2) do
      [key, value] ->
        if valid_key?(key) and valid_value?(value), do: [{key, value}], else: []

      _ ->
        []
    end
  end

  @spec valid_key?(key :: term()) :: boolean()
  defp valid_key?(key) when is_binary(key), do: Regex.match?(@key_regex, key)
  defp valid_key?(_), do: false

  @spec valid_value?(value :: term()) :: boolean()
  defp valid_value?(value) when is_binary(value), do: Regex.match?(@value_regex, value)
  defp valid_value?(_), do: false
end
