defmodule Otel.API.Ctx do
  @moduledoc """
  OTel Context for propagating values within a process.

  A `Context` is a plain map. The spec's required operations take a
  Context as an explicit argument and return either a value
  (`get_value/2`) or a new Context (`set_value/3`). Three optional
  global operations (`get_current/0`, `attach/1`, `detach/1`) provide
  implicit "current Context" management backed by the process
  dictionary.

  Callers who want "return default when key is missing" semantics
  compose either `Map.get(ctx, key, default)` style or
  `get_value(ctx, key) || default` at the call site, depending on
  which behavior they want for falsy values.

  At the API level (without SDK) values set here are only visible to
  the current process. All functions are safe for concurrent use.
  """

  @type t :: map()
  @type key :: term()
  @type value :: term()
  @opaque token :: t()

  @current_key {__MODULE__, :current}

  @doc """
  Returns the given name unchanged as a context key.

  The spec (`context/README.md` L63-67) requires `CreateKey` to accept
  a name and return an opaque object representing the key. In BEAM the
  caller-supplied term (typically an atom or a `{module, name}` tuple)
  is already a suitable key, so this returns it verbatim. Callers who
  need runtime uniqueness are expected to supply it themselves (e.g.
  `{__MODULE__, make_ref()}`).
  """
  @spec create_key(name :: term()) :: key()
  def create_key(name), do: name

  @doc """
  Gets a value from the given context.

  Returns `nil` when the key is not present.
  """
  @spec get_value(ctx :: t(), key :: key()) :: value()
  def get_value(ctx, key), do: Map.get(ctx, key)

  @doc """
  Sets a value in the given context, returning a new context.
  """
  @spec set_value(ctx :: t(), key :: key(), value :: value()) :: t()
  def set_value(ctx, key, value), do: Map.put(ctx, key, value)

  @doc """
  Returns the current process context. Empty map when nothing is
  attached.
  """
  @spec get_current() :: t()
  def get_current do
    Process.get(@current_key) || %{}
  end

  @doc """
  Attaches the given context to the current process.

  Returns a token that can be passed to `detach/1` to restore the
  previous context. On the first attach in a process, the previous
  context is normalized to an empty map.
  """
  @spec attach(ctx :: t()) :: token()
  def attach(ctx) do
    Process.put(@current_key, ctx) || %{}
  end

  @doc """
  Restores a previous context from a token returned by `attach/1`.
  """
  @spec detach(token :: token()) :: :ok
  def detach(token) do
    Process.put(@current_key, token)
    :ok
  end
end
