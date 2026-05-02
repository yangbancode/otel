defmodule Otel.Trace.TraceState do
  @moduledoc """
  W3C Trace Context `tracestate` field (spec §3.3).

  An opaque, immutable, ordered list of vendor-specific key/value
  pairs propagated alongside the `traceparent` header across tracing
  systems. Values are opaque to OpenTelemetry — each vendor owns
  its own key's semantics.

  ## Public API

  | Function | Role |
  |---|---|
  | `get/2`, `add/3`, `update/3`, `delete/2` | **Application** (OTel API MUST) |
  | `encode/1` | **Application** (W3C header serialization) |
  | `decode/1` | **Application** (W3C header parsing) |
  | `valid_key?/1`, `valid_value?/1` | **Application** (W3C format predicate) |
  | `new/0`, `empty?/1` | **Application** (Convenience) |

  ## References

  - W3C Trace Context: `w3c-trace-context/spec/20-http_request_header_format.md`
  - OTel Trace API: `opentelemetry-specification/specification/trace/api.md`
  """

  @typedoc """
  A W3C TraceState key (spec §3.3.1.3.1, Level 2).

  Must begin with a lowercase letter (`a-z`) or digit (`0-9`),
  followed by up to 255 characters from
  `[a-z0-9_\\-*/@]` (total ≤256 characters).

  Invalid keys are silently dropped by mutating operations and
  decoders.
  """
  @type key :: String.t()

  @typedoc """
  A W3C TraceState value (spec §3.3.1.3.2).

  Printable ASCII (0x20–0x7E) excluding `,` (0x2C) and `=` (0x3D),
  1–256 characters; the last character MUST NOT be a space.

  Invalid values are silently dropped by mutating operations and
  decoders.
  """
  @type value :: String.t()

  @typedoc """
  An opaque W3C TraceState (spec §3.3.1.2 `list`).

  External code must use the public API (`new/0`, `add/3`,
  `update/3`, `delete/2`, `decode/1`) to construct or mutate. The
  internal representation (an ordered `[{key, value}]` list, newest
  at the front per W3C §3.5 Mutating rules) is not part of the
  public contract.
  """
  @opaque t :: %__MODULE__{members: [{key(), value()}]}

  defstruct members: []

  # W3C §3.3.1.1: "There can be a maximum of 32 list-members in a list."
  @max_members 32

  # W3C §3.3.1.3.1 key grammar (Level 2, see @typedoc `key/0`):
  #   key     = (lcalpha / DIGIT) 0*255(keychar)
  #   keychar = lcalpha / DIGIT / "_" / "-" / "*" / "/" / "@"
  @key_regex ~r/^[a-z0-9][a-z0-9_\-*\/@]{0,255}$/

  # W3C §3.3.1.3.2 value grammar (L310-L312, see @typedoc `value/0`):
  #   value    = 0*255(chr) nblk-chr
  #   nblk-chr = %x21-2B / %x2D-3C / %x3E-7E
  #   chr      = %x20 / nblk-chr
  #
  # Regex character-range breakdown — derived directly from that ABNF:
  #   ` -+` : space to +   (0x20-0x2B) — `chr` lower band, excludes 0x2C (",")
  #   `--<` : hyphen to <  (0x2D-0x3C) — between "," and "="
  #   `>-~` : > to ~       (0x3E-0x7E) — above "=" (0x3D)
  #
  # `opentelemetry-erlang otel_tracestate` implements the same ranges —
  # both sides follow W3C §3.3.1.3.2; this is not a copy-from-erlang.
  @value_regex ~r/^[ -+--<>-~]{0,255}[!-+--<>-~]$/

  @doc """
  **Application** (OTel API MUST) — "Get value" (`trace/api.md`
  TraceState).

  Returns the value associated with `key`, or `""` (empty string)
  when the key is absent.

  Because W3C §3.3.1.3.2 forbids empty values, a well-formed state
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
  **Application** (OTel API MUST) — "Add a new key/value pair"
  (`trace/api.md` TraceState).

  Prepends a new `{key, value}` entry per W3C §3.5 Mutating:
  "The new key/value pair SHOULD be added to the beginning of the
  list."

  Returns the state unchanged when:

  - the key violates W3C §3.3.1.3.1 format,
  - the value violates W3C §3.3.1.3.2 format, or
  - `key` is already present. W3C §3.5 requires that "Adding a
    key/value pair MUST NOT result in the same key being present
    multiple times" — for "update-or-add" semantics use `update/3`.

  If adding would push the list past 32 entries, the right-most
  (oldest) entry is dropped per W3C §3.3.1.1: "If adding an entry
  would cause the `tracestate` list to contain more than 32
  `list-members` the right-most `list-member` should be removed
  from the list."
  """
  @spec add(trace_state :: t(), key :: key(), value :: value()) :: t()
  def add(%__MODULE__{members: members} = ts, key, value) do
    cond do
      not valid_key?(key) -> ts
      not valid_value?(value) -> ts
      List.keymember?(members, key, 0) -> ts
      true -> %__MODULE__{ts | members: Enum.take([{key, value} | members], @max_members)}
    end
  end

  @doc """
  **Application** (OTel API MUST) — "Update an existing value"
  (`trace/api.md` TraceState).

  Removes the existing entry for `key` and prepends a new entry
  with `value`. Per W3C §3.5: "Modified keys MUST be moved to the
  beginning (left) of the list."

  If `key` is not already present, the behaviour is equivalent to
  `add/3`, including the 32-member cap (W3C §3.3.1.1) — the
  right-most entry is dropped to make room.

  Returns the state unchanged when the key or value is invalid per
  W3C §3.3.1.3.1 / §3.3.1.3.2.
  """
  @spec update(trace_state :: t(), key :: key(), value :: value()) :: t()
  def update(%__MODULE__{members: members} = ts, key, value) do
    cond do
      not valid_key?(key) ->
        ts

      not valid_value?(value) ->
        ts

      List.keymember?(members, key, 0) ->
        %__MODULE__{ts | members: [{key, value} | List.keydelete(members, key, 0)]}

      true ->
        add(ts, key, value)
    end
  end

  @doc """
  **Application** (OTel API MUST) — "Delete a key/value pair"
  (`trace/api.md` TraceState).

  Removes the entry for `key`, if present. No-op when `key` is
  absent.
  """
  @spec delete(trace_state :: t(), key :: key()) :: t()
  def delete(%__MODULE__{members: members} = ts, key) do
    %__MODULE__{ts | members: List.keydelete(members, key, 0)}
  end

  @doc """
  **Application** (W3C header serialization) — §3.3.1.4 Combined
  Header Value.

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
  **Application** (W3C header parsing) — §3.3.1 `tracestate
  Header Field Values`.

  Splits a W3C `tracestate` header value into `{key, value}`
  entries, collapsing duplicate keys to the last occurrence.

  This function performs **parsing only** — it does not validate
  individual key/value format (W3C §3.3.1.6 grants parsers
  discretion on partially-parsed pairs) nor enforce the 32
  list-member cap (W3C §3.3.1.1 is an "adding" rule). Validation
  is applied at mutation time by `add/3` / `update/3` per
  OTel api.md L294-L295. Pairs without `=` raise `MatchError`.

  Used by `Otel.API.Propagator.TextMap.TraceContext` when
  extracting incoming requests.
  """
  @spec decode(header :: String.t()) :: t()
  def decode(header) do
    members =
      header
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.reduce([], fn pair, acc ->
        [key, value] = String.split(pair, "=", parts: 2)
        List.keystore(acc, key, 0, {key, value})
      end)

    %__MODULE__{members: members}
  end

  @doc """
  **Application** (W3C format predicate) — key (§3.3.1.3.1).

  Returns whether `key` conforms to the W3C TraceState key format.
  See `t:key/0` for the grammar. Returns `false` for any non-binary
  input.
  """
  @spec valid_key?(key :: term()) :: boolean()
  def valid_key?(key) when is_binary(key), do: Regex.match?(@key_regex, key)
  def valid_key?(_), do: false

  @doc """
  **Application** (W3C format predicate) — value (§3.3.1.3.2).

  Returns whether `value` conforms to the W3C TraceState value
  format. See `t:value/0` for the grammar. Returns `false` for any
  non-binary input.
  """
  @spec valid_value?(value :: term()) :: boolean()
  def valid_value?(value) when is_binary(value), do: Regex.match?(@value_regex, value)
  def valid_value?(_), do: false

  @doc """
  **Application** (Convenience) — build an empty TraceState.

  Returns a new (empty) TraceState. Preferred over `%TraceState{}`
  at external call sites because `t/0` is opaque.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  **Application** (Convenience) — empty-state predicate.

  Returns whether the TraceState has no entries.

  Used by `Otel.API.Propagator.TextMap.TraceContext` to skip
  injecting an empty `tracestate` header (W3C §3.3.1 L275:
  "SHOULD avoid sending [empty headers]").
  """
  @spec empty?(trace_state :: t()) :: boolean()
  def empty?(%__MODULE__{members: []}), do: true
  def empty?(%__MODULE__{}), do: false
end
