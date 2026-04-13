defmodule Otel.API.Baggage do
  @moduledoc """
  Baggage API for propagating name/value pairs across service boundaries.

  Baggage is an immutable map stored in Context. Each name is associated
  with exactly one value and optional metadata. Names and values are
  case-sensitive UTF-8 strings.

  Fully functional without an installed SDK.
  """

  @type value :: String.t()
  @type metadata :: String.t()
  @type entry :: {value(), metadata()}
  @type t :: %{String.t() => entry()}

  @baggage_key :"__otel.baggage__"

  # --- Operations on Baggage maps ---

  @doc """
  Returns the value for `name`, or nil if not found.
  """
  @spec get_value(baggage :: t(), name :: String.t()) :: value() | nil
  def get_value(baggage, name) when is_map(baggage) do
    case Map.get(baggage, name) do
      {value, _metadata} -> value
      nil -> nil
    end
  end

  @doc """
  Returns all entries as a map of `%{name => {value, metadata}}`.
  """
  @spec get_all(baggage :: t()) :: t()
  def get_all(baggage) when is_map(baggage), do: baggage

  @doc """
  Sets a name/value pair. Returns a new Baggage.

  If name already exists, the new value takes precedence.
  """
  @spec set_value(baggage :: t(), name :: String.t(), value :: value(), metadata :: metadata()) ::
          t()
  def set_value(baggage, name, value, metadata \\ "") when is_map(baggage) do
    Map.put(baggage, name, {value, metadata})
  end

  @doc """
  Removes the entry for `name`. Returns a new Baggage.
  """
  @spec remove_value(baggage :: t(), name :: String.t()) :: t()
  def remove_value(baggage, name) when is_map(baggage) do
    Map.delete(baggage, name)
  end

  # --- Context interaction ---

  @doc """
  Returns the Baggage from the given context.
  """
  @spec get_baggage(ctx :: Otel.API.Ctx.t()) :: t()
  def get_baggage(ctx) do
    Otel.API.Ctx.get_value(ctx, @baggage_key, %{})
  end

  @doc """
  Returns a new context with the given Baggage set.
  """
  @spec set_baggage(ctx :: Otel.API.Ctx.t(), baggage :: t()) :: Otel.API.Ctx.t()
  def set_baggage(ctx, baggage) when is_map(baggage) do
    Otel.API.Ctx.set_value(ctx, @baggage_key, baggage)
  end

  @doc """
  Returns the Baggage from the implicit (process) context.
  """
  @spec get_baggage() :: t()
  def get_baggage do
    Otel.API.Ctx.get_value(@baggage_key, %{})
  end

  @doc """
  Sets the Baggage in the implicit (process) context.
  """
  @spec set_baggage(baggage :: t()) :: :ok
  def set_baggage(baggage) when is_map(baggage) do
    Otel.API.Ctx.set_value(@baggage_key, baggage)
  end

  @doc """
  Returns a new context with all baggage entries removed.
  """
  @spec clear(ctx :: Otel.API.Ctx.t()) :: Otel.API.Ctx.t()
  def clear(ctx) do
    Otel.API.Ctx.set_value(ctx, @baggage_key, %{})
  end

  @doc """
  Clears all baggage entries from the implicit (process) context.
  """
  @spec clear() :: :ok
  def clear do
    Otel.API.Ctx.set_value(@baggage_key, %{})
  end
end
