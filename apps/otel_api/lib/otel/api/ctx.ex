defmodule Otel.API.Ctx do
  @moduledoc """
  OTel Context for propagating values within a process.

  Context is a plain map stored in the process dictionary.
  Tracer and Baggage modules handle updating the context;
  users rarely need to interact with this module directly.

  Functions come in two variants:
  - Implicit (1-2 arity): operate on the current process context
  - Explicit (2-3 arity): operate on a given context map
  """

  @type t :: map()
  @type key :: term()
  @type value :: term()
  @opaque token :: t() | nil

  @ctx_key :"__otel.ctx__"

  @doc """
  Creates a new opaque context key.

  Multiple calls with the same name return different keys (L65).
  The name exists for debugging purposes and does not uniquely
  identify the key (L65). Uniqueness is guaranteed by `make_ref/0`.
  """
  @spec create_key(name :: term()) :: key()
  def create_key(name), do: {name, make_ref()}

  @doc """
  Returns an empty context.
  """
  @spec new() :: t()
  def new, do: %{}

  # --- Implicit (current process context) ---

  @doc """
  Sets a value in the current process context.
  """
  @spec set_value(key :: key(), value :: value()) :: :ok
  def set_value(key, value) do
    Process.put(@ctx_key, Map.put(get_current(), key, value))
    :ok
  end

  @doc """
  Gets a value from the current process context.

  Returns `nil` if the key is not found.
  """
  @spec get_value(key :: key()) :: value()
  def get_value(key) do
    Map.get(get_current(), key)
  end

  @doc """
  Gets a value from the current process context with a default.
  """
  @spec get_value(key :: key(), default :: value()) :: value()
  def get_value(key, default) when not is_map(key) do
    Map.get(get_current(), key, default)
  end

  @doc """
  Removes a key from the current process context.
  """
  @spec remove(key :: key()) :: :ok
  def remove(key) do
    Process.put(@ctx_key, Map.delete(get_current(), key))
    :ok
  end

  @doc """
  Clears all values from the current process context.
  """
  @spec clear() :: :ok
  def clear do
    Process.delete(@ctx_key)
    :ok
  end

  # --- Explicit (given context) ---

  @doc """
  Sets a value in the given context, returning a new context.
  """
  @spec set_value(ctx :: t(), key :: key(), value :: value()) :: t()
  def set_value(ctx, key, value) when is_map(ctx) do
    Map.put(ctx, key, value)
  end

  @doc """
  Gets a value from the given context.
  """
  @spec get_value(ctx :: t(), key :: key(), default :: value()) :: value()
  def get_value(ctx, key, default) when is_map(ctx) do
    Map.get(ctx, key, default)
  end

  @doc """
  Removes a key from the given context, returning a new context.
  """
  @spec remove(ctx :: t(), key :: key()) :: t()
  def remove(ctx, key) when is_map(ctx), do: Map.delete(ctx, key)

  @doc """
  Clears all values from the given context.
  """
  @spec clear(ctx :: t()) :: t()
  def clear(_ctx), do: new()

  # --- Attach / Detach ---

  @doc """
  Returns the current process context.
  """
  @spec get_current() :: t()
  def get_current do
    Process.get(@ctx_key) || %{}
  end

  @doc """
  Attaches the given context to the current process.

  Returns a token that can be passed to `detach/1` to restore
  the previous context.
  """
  @spec attach(ctx :: t()) :: token()
  def attach(ctx) do
    Process.put(@ctx_key, ctx)
  end

  @doc """
  Restores a previous context from a token returned by `attach/1`.
  """
  @spec detach(token :: token()) :: t() | nil
  def detach(token) do
    Process.put(@ctx_key, token)
  end
end
