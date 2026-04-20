defmodule Otel.API.Trace.TraceState do
  @moduledoc """
  W3C Trace Context `tracestate` field (spec §3.3).

  An opaque, immutable, ordered list of vendor-specific key/value
  pairs propagated alongside the `traceparent` header across tracing
  systems. Values are opaque to OpenTelemetry — each vendor owns
  its own key's semantics.

  ## Public API

  | Function | Role |
  |---|---|
  | `get/2`, `add/3`, `update/3`, `delete/2` | **OTel API MUST** |
  | `encode/1`, `decode/1` | **W3C header serialization** |
  | `valid_key?/1`, `valid_value?/1` | **W3C format predicate** |
  | `new/0`, `size/1` | **Local helper** (not in spec) |

  ## References

  - W3C Trace Context: <https://www.w3.org/TR/trace-context/>
  - OTel Trace API: `opentelemetry-specification/specification/trace/api.md`
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
  1–256 characters; the last character MUST NOT be a space.

  Invalid values are silently dropped by mutating operations and
  decoders.
  """
  @type value :: String.t()

  @typedoc """
  An opaque W3C TraceState (spec §3.3.1).

  External code must use the public API (`new/0`, `add/3`,
  `update/3`, `delete/2`, `decode/1`) to construct or mutate. The
  internal representation (an ordered `[{key, value}]` list, newest
  at the front per W3C §3.3.3) is not part of the public contract.
  """
  @opaque t :: %__MODULE__{members: [{key(), value()}]}

  defstruct members: []

  # W3C §3.3.3: the list MUST contain at most 32 members.
  @max_members 32

  # W3C §3.3.3: the encoded header value MUST be at most 512 bytes.
  @max_header_bytes 512

  # W3C §3.3.1.1 key grammar (see @typedoc `key/0`).
  @key_regex ~r/^([a-z][a-z0-9_\-*\/]{0,255}|[a-z0-9][a-z0-9_\-*\/]{0,240}@[a-z][a-z0-9_\-*\/]{0,13})$/

  # W3C §3.3.2 value grammar (see @typedoc `value/0`).
  # Character-range breakdown (matches `opentelemetry-erlang otel_tracestate`):
  #   ` -+` : space to +   (0x20-0x2B) — before ","
  #   `--<` : hyphen to <  (0x2D-0x3C) — between "," and "="
  #   `>-~` : > to ~       (0x3E-0x7E) — after "="
  @value_regex ~r/^[ -+--<>-~]{0,255}[!-+--<>-~]$/

  @doc """
  **OTel API MUST** — "Get value" (`trace/api.md` TraceState).

  Returns the value associated with `key`, or `""` (empty string)
  when the key is absent.

  Because W3C §3.3.2 forbids empty values, a well-formed state
  cannot contain one — the empty-string return reliably signals
  "not found".
  """
  @spec get(trace_state :: t(), key :: key()) :: value()
  def get(%__MODULE__{members: members}, key) do
    case List.keyfind(members, key, 0) do
      {_, value} -> value
      nil -> ""
    end
  end

  @doc """
  **OTel API MUST** — "Add a new key/value pair" (`trace/api.md` TraceState).

  Prepends a new `{key, value}` entry to the list (W3C §3.3.3: new
  entries MUST be added at the left).

  Returns the state unchanged when:

  - the key violates W3C §3.3.1.1 format,
  - the value violates W3C §3.3.2 format, or
  - the list already contains 32 entries (W3C §3.3.3).

  No existing-key check is performed; for "update-or-add" semantics
  use `update/3` instead.
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
  **OTel API MUST** — "Update an existing value" (`trace/api.md` TraceState).

  Removes any existing entry for `key` and prepends a new entry
  with `value`. Per W3C §3.3.3, updated entries move to the front
  of the list to signal "most recently mutated by this system".

  If `key` is not already present, the behaviour is equivalent to
  `add/3`, including the 32-member limit.

  Returns the state unchanged when the key or value is invalid per
  W3C §3.3.1.1 / §3.3.2.
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
  **OTel API MUST** — "Delete a key/value pair" (`trace/api.md` TraceState).

  Removes the entry for `key`, if present. No-op when `key` is
  absent.
  """
  @spec delete(trace_state :: t(), key :: key()) :: t()
  def delete(%__MODULE__{members: members} = ts, key) do
    %__MODULE__{ts | members: List.keydelete(members, key, 0)}
  end

  @doc """
  **W3C header serialization** (§3.3.1).

  Serializes to a W3C `tracestate` header value. Returns `""` for
  an empty state.

  Used by `Otel.API.Propagator.TextMap.TraceContext` when injecting
  outgoing requests.
  """
  @spec encode(trace_state :: t()) :: String.t()
  def encode(%__MODULE__{members: []}), do: ""

  def encode(%__MODULE__{members: members}) do
    Enum.map_join(members, ",", fn {key, value} -> "#{key}=#{value}" end)
  end

  @doc """
  **W3C header parsing** (§3.3.3).

  Parses a W3C `tracestate` header value. Returns an **empty**
  state when:

  - the header exceeds 512 bytes (W3C §3.3.3 size limit), or
  - the header contains more than 32 list-members (W3C §3.3.3:
    "the parser MUST discard the whole tracestate").

  Otherwise individual malformed entries (bad key/value format or
  missing `=`) are dropped while the remainder is kept; duplicate
  keys collapse to the last occurrence.

  Used by `Otel.API.Propagator.TextMap.TraceContext` when
  extracting incoming requests.
  """
  @spec decode(header :: String.t()) :: t()
  def decode(header) when is_binary(header) do
    if byte_size(header) > @max_header_bytes do
      %__MODULE__{}
    else
      build_from_header(header)
    end
  end

  @doc """
  **W3C format predicate** — key (§3.3.1.1).

  Returns whether `key` conforms to the W3C TraceState key format.
  See `t:key/0` for the grammar. Returns `false` for any non-binary
  input.
  """
  @spec valid_key?(key :: term()) :: boolean()
  def valid_key?(key) when is_binary(key), do: Regex.match?(@key_regex, key)
  def valid_key?(_), do: false

  @doc """
  **W3C format predicate** — value (§3.3.2).

  Returns whether `value` conforms to the W3C TraceState value
  format. See `t:value/0` for the grammar. Returns `false` for any
  non-binary input.
  """
  @spec valid_value?(value :: term()) :: boolean()
  def valid_value?(value) when is_binary(value), do: Regex.match?(@value_regex, value)
  def valid_value?(_), do: false

  @doc """
  **Local helper** (not in spec).

  Returns a new (empty) TraceState. Preferred over `%TraceState{}`
  at external call sites because `t/0` is opaque.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  **Local helper** (not in spec).

  Returns the number of entries.
  """
  @spec size(trace_state :: t()) :: non_neg_integer()
  def size(%__MODULE__{members: members}), do: length(members)

  # --- Private ---

  @spec build_from_header(header :: String.t()) :: t()
  defp build_from_header(header) do
    pairs =
      header
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if length(pairs) > @max_members do
      %__MODULE__{}
    else
      members =
        pairs
        |> Enum.flat_map(&parse_pair/1)
        |> Enum.reduce([], fn {key, value}, acc ->
          List.keystore(acc, key, 0, {key, value})
        end)

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
end
