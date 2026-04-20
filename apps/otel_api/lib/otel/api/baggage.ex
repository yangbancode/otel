defmodule Otel.API.Baggage do
  @moduledoc """
  Baggage API for propagating name/value pairs across service boundaries.

  Baggage is an immutable map stored in Context. Each name is associated
  with exactly one value and optional metadata. Names and values are
  case-sensitive UTF-8 strings.

  The module exposes two layers that mirror the spec's structure:

  - **Operations on Baggage** (`get_value/2`, `get_all/1`, `set_value/4`,
    `remove_value/2`) — pure functions on a Baggage value (spec MUST).
  - **Context interaction** (`current/0`, `current/1`, `set_current/1`,
    `set_current/2`) — read/write the Baggage stored in a Context. The
    spec treats Context interaction as whole-Baggage operations; per-
    entry changes happen on the Baggage value and are then written back.

  Clearing: per spec, clearing is accomplished by writing an empty
  Baggage into the Context — `set_current(%{})` for the implicit
  context or `set_current(ctx, %{})` for an explicit one. No dedicated
  `clear/0` or `clear/1` is provided.

  Fully functional without an installed SDK.
  """

  @type value :: String.t()

  @typedoc """
  Opaque property string attached to a baggage entry.

  Per W3C Baggage § 3.3 and RFC 9110, metadata is carried in the
  `baggage` header as US-ASCII `property` tokens. Callers MUST supply
  a string that is valid in the W3C header grammar (US-ASCII, no `,`
  or `;` characters). The API does not validate or encode metadata —
  it is written verbatim on inject.
  """
  @type metadata :: String.t()

  @type entry :: {value(), metadata()}
  @type t :: %{String.t() => entry()}

  @current_key {__MODULE__, :current}

  # --- Operations on Baggage (spec MUST, pure) ---

  @doc """
  Returns the value for `name`, or nil if not found.
  """
  @spec get_value(baggage :: t(), name :: String.t()) :: value() | nil
  def get_value(baggage, name) do
    case Map.get(baggage, name) do
      {value, _metadata} -> value
      nil -> nil
    end
  end

  @doc """
  Returns all entries as a map of `%{name => {value, metadata}}`.
  """
  @spec get_all(baggage :: t()) :: t()
  def get_all(baggage), do: baggage

  @doc """
  Sets a name/value pair. Returns a new Baggage.

  If name already exists, the new value takes precedence (spec
  "Conflict Resolution").
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
  Removes the entry for `name`. Returns a new Baggage.
  """
  @spec remove_value(baggage :: t(), name :: String.t()) :: t()
  def remove_value(baggage, name) do
    Map.delete(baggage, name)
  end

  # --- Context interaction (spec MUST for explicit, SHOULD for implicit) ---

  @doc """
  Returns the current Baggage from the implicit (process) context.
  """
  @spec current() :: t()
  def current do
    Otel.API.Ctx.get_value(@current_key) || %{}
  end

  @doc """
  Returns the Baggage from the given context.
  """
  @spec current(ctx :: Otel.API.Ctx.t()) :: t()
  def current(ctx) do
    Otel.API.Ctx.get_value(ctx, @current_key) || %{}
  end

  @doc """
  Sets the Baggage in the implicit (process) context, replacing any
  existing Baggage.
  """
  @spec set_current(baggage :: t()) :: :ok
  def set_current(baggage) do
    Otel.API.Ctx.set_value(@current_key, baggage)
  end

  @doc """
  Returns a new context with the given Baggage set, replacing any
  existing Baggage.
  """
  @spec set_current(ctx :: Otel.API.Ctx.t(), baggage :: t()) :: Otel.API.Ctx.t()
  def set_current(ctx, baggage) do
    Otel.API.Ctx.set_value(ctx, @current_key, baggage)
  end
end
