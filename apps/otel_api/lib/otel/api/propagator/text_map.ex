defmodule Otel.API.Propagator.TextMap do
  @moduledoc """
  TextMapPropagator behaviour for context propagation via string key/value pairs.

  Propagators inject values into and extract values from carriers.
  A carrier is a generic container (typically HTTP headers) accessed
  through getter and setter functions.

  Key/value pairs MUST only consist of US-ASCII characters valid
  for HTTP header fields (RFC 9110).
  """

  @type carrier :: term()
  @type getter :: (carrier(), key :: String.t() -> String.t() | nil)
  @type setter :: (key :: String.t(), value :: String.t(), carrier() -> carrier())

  @doc """
  Injects values from the context into the carrier.
  """
  @callback inject(
              ctx :: Otel.API.Ctx.t(),
              carrier :: carrier(),
              setter :: setter()
            ) :: carrier()

  @doc """
  Extracts values from the carrier into a new context.

  MUST NOT throw on parse failure. MUST NOT store invalid values.
  """
  @callback extract(
              ctx :: Otel.API.Ctx.t(),
              carrier :: carrier(),
              getter :: getter()
            ) :: Otel.API.Ctx.t()

  @doc """
  Returns the list of header keys the propagator uses.
  """
  @callback fields() :: [String.t()]

  # --- Default carrier functions for [{binary, binary}] ---

  @doc """
  Default getter for `[{String.t(), String.t()}]` carriers.

  Case-insensitive key lookup, returns first matching value or nil.
  """
  @spec default_getter(carrier :: [{String.t(), String.t()}], key :: String.t()) ::
          String.t() | nil
  def default_getter(carrier, key) when is_list(carrier) do
    lower_key = String.downcase(key)

    Enum.find_value(carrier, fn {k, v} ->
      if String.downcase(k) == lower_key, do: v
    end)
  end

  @doc """
  Default setter for `[{String.t(), String.t()}]` carriers.

  Replaces existing key (case-insensitive) or appends.
  """
  @spec default_setter(
          key :: String.t(),
          value :: String.t(),
          carrier :: [{String.t(), String.t()}]
        ) ::
          [{String.t(), String.t()}]
  def default_setter(key, value, carrier) when is_list(carrier) do
    lower_key = String.downcase(key)
    filtered = Enum.reject(carrier, fn {k, _v} -> String.downcase(k) == lower_key end)
    filtered ++ [{key, value}]
  end

  @doc """
  Default keys function for `[{String.t(), String.t()}]` carriers.

  Returns all keys in the carrier.
  """
  @spec default_keys(carrier :: [{String.t(), String.t()}]) :: [String.t()]
  def default_keys(carrier) when is_list(carrier) do
    Enum.map(carrier, fn {k, _v} -> k end)
  end

  # --- Convenience functions using global propagator ---

  @doc """
  Injects context using the global text map propagator.
  """
  @spec inject(ctx :: Otel.API.Ctx.t(), carrier :: carrier(), setter :: setter()) :: carrier()
  def inject(ctx, carrier, setter \\ &default_setter/3) do
    case Otel.API.Propagator.get_text_map_propagator() do
      nil -> carrier
      propagator -> inject_with(propagator, ctx, carrier, setter)
    end
  end

  @doc """
  Extracts context using the global text map propagator.
  """
  @spec extract(ctx :: Otel.API.Ctx.t(), carrier :: carrier(), getter :: getter()) ::
          Otel.API.Ctx.t()
  def extract(ctx, carrier, getter \\ &default_getter/2) do
    case Otel.API.Propagator.get_text_map_propagator() do
      nil -> ctx
      propagator -> extract_with(propagator, ctx, carrier, getter)
    end
  end

  @doc false
  @spec inject_with(
          propagator :: {module(), term()} | module(),
          ctx :: Otel.API.Ctx.t(),
          carrier :: carrier(),
          setter :: setter()
        ) :: carrier()
  def inject_with({module, opts}, ctx, carrier, setter) do
    module.inject(opts, ctx, carrier, setter)
  end

  def inject_with(module, ctx, carrier, setter) when is_atom(module) do
    module.inject(ctx, carrier, setter)
  end

  @doc false
  @spec extract_with(
          propagator :: {module(), term()} | module(),
          ctx :: Otel.API.Ctx.t(),
          carrier :: carrier(),
          getter :: getter()
        ) :: Otel.API.Ctx.t()
  def extract_with({module, opts}, ctx, carrier, getter) do
    module.extract(opts, ctx, carrier, getter)
  end

  def extract_with(module, ctx, carrier, getter) when is_atom(module) do
    module.extract(ctx, carrier, getter)
  end
end
