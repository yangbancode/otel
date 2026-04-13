defmodule Otel.API.Propagator do
  @moduledoc """
  Global propagator registration and retrieval.

  Uses `persistent_term` for storage. Without explicit configuration,
  returns nil (no-op behavior — carriers pass through unchanged).
  """

  @propagator_key :"__otel.propagator.text_map__"

  @doc """
  Returns the global text map propagator, or nil if none is set.
  """
  @spec get_text_map_propagator() :: {module(), term()} | module() | nil
  def get_text_map_propagator do
    :persistent_term.get(@propagator_key, nil)
  end

  @doc """
  Sets the global text map propagator.

  Accepts a module or `{module, opts}` tuple.
  """
  @spec set_text_map_propagator(propagator :: {module(), term()} | module()) :: :ok
  def set_text_map_propagator(propagator) do
    :persistent_term.put(@propagator_key, propagator)
    :ok
  end
end
