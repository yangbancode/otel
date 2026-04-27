defmodule Otel.API.Baggage do
  @moduledoc """
  OTel Baggage (spec `baggage/api.md`, Status: **Stable**).

  A set of name/value pairs (with optional metadata per entry)
  propagated across service boundaries. Each name is associated
  with exactly one value; names and values are case-sensitive
  UTF-8 strings per spec L43-L58.

  The module exposes two layers that mirror the spec's structure:

  - **Operations on Baggage** — pure functions on a Baggage value
    (§Operations, L87-L136).
  - **Context interaction** — read/write the Baggage stored under
    this module's reserved key inside a `Otel.API.Ctx.t()`
    (§Context Interaction, L138-L167). Arity-1/2 are the MUST
    explicit forms; arity-0/1 are the SHOULD implicit forms for
    languages with an ambient context (Elixir).

    `current` names the "current-role slot" inside a Context —
    i.e. the Baggage stored under the reserved key. Same idiom as
    `opentelemetry-erlang`'s `otel_tracer:current_span_ctx/1`.

  Clearing: per spec §Clear Baggage in the Context (L169-L176),
  clearing is accomplished by writing an empty Baggage into the
  Context — `set_current(%{})` for the implicit context or
  `set_current(ctx, %{})` for an explicit one. No dedicated
  `clear/0` or `clear/1` is provided (spec allows either path).

  The Baggage API MUST be fully functional without an installed
  SDK (spec L79-L82) — this module is.

  ## Public API

  | Function | Role |
  |---|---|
  | `get_value/2`, `get_all/1`, `set_value/4`, `remove_value/2` | **Application** (OTel API MUST) — Operations (L87-L136) |
  | `current/1`, `set_current/2` | **Application** (OTel API MUST) — Context Interaction (L143-L151) |
  | `current/0`, `set_current/1` | **Application** (OTel API SHOULD) — implicit-context variants (L153-L167) |

  ## References

  - OTel Baggage API: `opentelemetry-specification/specification/baggage/api.md`
  - W3C Baggage HTTP Header Format: `w3c-baggage/baggage/HTTP_HEADER_FORMAT.md`
  """

  @typedoc """
  A Baggage container (spec `baggage/api.md` §Overview).

  A map from name (`String.t()`) to `{value, metadata}` tuples.
  Per spec L37-L41 "Baggage is represented as a set of name/value
  pairs ... Each name in Baggage MUST be associated with exactly
  one value". Per spec L84-L85 the container MUST be immutable —
  all mutation operations return a new map.
  """
  @type t :: %{String.t() => entry()}

  @typedoc """
  A baggage value (spec `baggage/api.md` §Overview, L53-L58).

  Any valid UTF-8 string. The API MUST accept any UTF-8 string in
  `set_value/4` and MUST return the same string from
  `get_value/2`. Names and values are case-sensitive per spec
  L57-L58.
  """
  @type value :: String.t()

  @typedoc """
  Opaque property string attached to a baggage entry.

  Per OTel `baggage/api.md` L122-L124: *"Metadata ... should be an
  opaque wrapper for a string with no semantic meaning. Left
  opaque to allow for future functionality"*. This module carries
  it verbatim.

  On the wire, metadata is serialized into the W3C `baggage`
  header's `property` production (W3C Baggage
  `HTTP_HEADER_FORMAT.md` §Header Content > Definition >
  property). Callers MUST supply a string that is valid in that
  grammar (US-ASCII `token`s and `baggage-octet`s, joined by `;`,
  no bare `,`). The API does not validate or encode metadata — it
  is written verbatim on inject.
  """
  @type metadata :: String.t()

  @typedoc """
  A baggage entry — a `{value, metadata}` tuple.

  Exposed by `get_all/1` so callers can read both the value and
  its metadata. For value-only access use `get_value/2`.
  """
  @type entry :: {value(), metadata()}

  @current_key {__MODULE__, :current}

  # --- Operations on Baggage (spec §Operations, MUST) ---

  @doc """
  **Application** (OTel API MUST) — "Get Value"
  (`baggage/api.md` L89-L98).

  Returns the value for `name`, or `nil` when the name is not
  present. Spec L91-L93: *"takes the name as input, and returns a
  value associated with the given name, or null if the given name
  is not present"*.
  """
  @spec get_value(baggage :: t(), name :: String.t()) :: value() | nil
  def get_value(baggage, name) do
    case Map.get(baggage, name) do
      {value, _metadata} -> value
      nil -> nil
    end
  end

  @doc """
  **Application** (OTel API MUST) — "Get All Values"
  (`baggage/api.md` L99-L104).

  Returns all entries as a map of `%{name => {value, metadata}}`.
  Per spec L101-L102 the order of name/value pairs MUST NOT be
  significant; Elixir maps already satisfy this.
  """
  @spec get_all(baggage :: t()) :: t()
  def get_all(baggage), do: baggage

  @doc """
  **Application** (OTel API MUST) — "Set Value"
  (`baggage/api.md` L106-L124).

  Returns a new Baggage with `name` mapped to `{value, metadata}`.
  If `name` already exists the new value takes precedence per
  §Conflict Resolution (L204-L208: *"the new pair MUST take
  precedence"*).

  `metadata` is optional per spec L120-L124 and defaults to the
  empty string.
  """
  @spec set_value(
          baggage :: t(),
          name :: String.t(),
          value :: value(),
          metadata :: metadata()
        ) :: t()
  def set_value(baggage, name, value, metadata \\ "") do
    Map.put(baggage, name, {value, metadata})
  end

  @doc """
  **Application** (OTel API MUST) — "Remove Value"
  (`baggage/api.md` L126-L136).

  Returns a new Baggage no longer containing `name`. Spec
  L128-L129: *"Returns a new Baggage which no longer contains the
  selected name"*.
  """
  @spec remove_value(baggage :: t(), name :: String.t()) :: t()
  def remove_value(baggage, name) do
    Map.delete(baggage, name)
  end

  # --- Context interaction (spec §Context Interaction) ---

  @doc """
  **Application** (OTel API SHOULD) — "Get current Baggage"
  (`baggage/api.md` L153-L159, implicit-context variant).

  Returns the Baggage stored under this module's reserved key in
  the implicit process Context, or an empty Baggage when none is
  attached. Equivalent to `current(Otel.API.Ctx.current())`.
  """
  @spec current() :: t()
  def current do
    Otel.API.Ctx.get_value(@current_key) || %{}
  end

  @doc """
  **Application** (OTel API MUST) — "Extract Baggage from
  Context" (`baggage/api.md` L143-L151).

  Returns the Baggage stored under this module's reserved key in
  `ctx`, or an empty Baggage when none is set. Per spec L149-L151
  *"API users SHOULD NOT have access to the Context Key used by
  the Baggage API implementation"* — the key is a private module
  attribute.
  """
  @spec current(ctx :: Otel.API.Ctx.t()) :: t()
  def current(ctx) do
    Otel.API.Ctx.get_value(ctx, @current_key) || %{}
  end

  @doc """
  **Application** (OTel API SHOULD) — "Set current Baggage"
  (`baggage/api.md` L153-L162, implicit-context variant).

  Sets `baggage` under this module's reserved key in the implicit
  process Context, replacing any existing Baggage.
  """
  @spec set_current(baggage :: t()) :: :ok
  def set_current(baggage) do
    Otel.API.Ctx.set_value(@current_key, baggage)
  end

  @doc """
  **Application** (OTel API MUST) — "Insert Baggage into
  Context" (`baggage/api.md` L143-L151).

  Returns a new Context with `baggage` set under this module's
  reserved key, replacing any existing Baggage.
  """
  @spec set_current(ctx :: Otel.API.Ctx.t(), baggage :: t()) :: Otel.API.Ctx.t()
  def set_current(ctx, baggage) do
    Otel.API.Ctx.set_value(ctx, @current_key, baggage)
  end
end
