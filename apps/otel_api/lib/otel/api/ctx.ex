defmodule Otel.API.Ctx do
  @moduledoc """
  OTel Context (spec `context/README.md`, Status: **Stable**).

  A propagation mechanism that carries execution-scoped values across
  API boundaries within a single process. Cross-cutting concerns
  (Trace, Baggage, …) store their values in the Context.

  A Context is represented as a plain map. The three spec-mandated
  operations (`create_key/1`, `get_value/2`, `set_value/3`) are pure
  and take a Context as an explicit argument. The three optional
  global operations (`current/0`, `attach/1`, `detach/1`) manage the
  "current" ambient Context via the process dictionary, as required
  for implicit-style usage (Elixir). Two convenience wrappers
  (`get_value/1`, `set_value/2`) read and write through the current
  Context for call sites that prefer the implicit form.

  Values stored in the current Context are only visible to the
  current process. Callers that want "return default when key is
  missing" semantics compose `get_value(...) || default` at the call
  site.

  ## Public API

  | Function | Role |
  |---|---|
  | `create_key/1`, `get_value/2`, `set_value/3` | **OTel API MUST** |
  | `current/0`, `attach/1`, `detach/1` | **OTel API (optional global)** |
  | `get_value/1`, `set_value/2` | **Local helper** (not in spec) |

  ## References

  - OTel Context: `opentelemetry-specification/specification/context/README.md`
  """

  @typedoc """
  An OTel Context (spec `context/README.md` §Overview).

  Implemented as a map from caller-supplied keys to arbitrary values.
  The map shape is part of the public contract — callers may
  construct an empty context as `%{}` or pass an existing map
  directly.

  Per spec "A Context MUST be immutable, and its write operations
  MUST result in the creation of a new Context". `set_value/3`
  returns a new map; the input is unchanged.
  """
  @type t :: map()

  @typedoc """
  A context key (spec `context/README.md` §Create a key, L63-L67).

  Per spec "The key name exists for debugging purposes and does not
  uniquely identify the key". In BEAM the caller-supplied term itself
  serves as the key — typically an atom or a `{module, name}` tuple.
  Callers that need runtime uniqueness are expected to supply it
  themselves (e.g. `{__MODULE__, make_ref()}`).
  """
  @type key :: term()

  @typedoc """
  A context value. Any Erlang term.
  """
  @type value :: term()

  @typedoc """
  An opaque token returned by `attach/1` and consumed by `detach/1`
  (spec `context/README.md` L113).

  Internally this is the Context that was current before the attach,
  but callers must treat it as opaque — the spec mandates a token
  abstraction.
  """
  @opaque token :: t()

  @current_key {__MODULE__, :current}

  @doc """
  **OTel API MUST** — "Create a key" (`context/README.md` L56-L67).

  Returns the given name unchanged as a context key.

  The spec requires `CreateKey` to accept a name and return an opaque
  object representing the key. In BEAM the caller-supplied term
  (typically an atom or a `{module, name}` tuple) is already a
  suitable key, so this returns it verbatim. Callers who need runtime
  uniqueness are expected to supply it themselves (e.g.
  `{__MODULE__, make_ref()}`).
  """
  @spec create_key(name :: term()) :: key()
  def create_key(name), do: name

  @doc """
  **OTel API MUST** — "Get value" (`context/README.md` L69-L79).

  Returns the value in `ctx` for `key`, or `nil` when the key is not
  present. Callers who want a default value compose
  `|| default` at the call site.
  """
  @spec get_value(ctx :: t(), key :: key()) :: value()
  def get_value(ctx, key), do: Map.get(ctx, key)

  @doc """
  **OTel API MUST** — "Set value" (`context/README.md` L81-L92).

  Returns a new Context with `key` mapped to `value`. The spec
  requires immutability — the input `ctx` is unchanged.
  """
  @spec set_value(ctx :: t(), key :: key(), value :: value()) :: t()
  def set_value(ctx, key, value), do: Map.put(ctx, key, value)

  @doc """
  **OTel API (optional global)** — "Get current Context"
  (`context/README.md` L101-L103).

  Returns the current process's Context, or an empty map when nothing
  is attached. Used by SDK components and instrumentation libraries
  to read the ambient Context. End-user code typically reads domain
  values through higher-level APIs (`Otel.API.Baggage.current/0`,
  `Otel.API.Trace.current_span/0`) rather than calling this directly.
  """
  @spec current() :: t()
  def current do
    Process.get(@current_key) || %{}
  end

  @doc """
  **OTel API (optional global)** — "Attach Context"
  (`context/README.md` L105-L117).

  Associates `ctx` with the current process and returns a token that
  can be passed to `detach/1` to restore the previous Context. On the
  first attach in a process, the previous Context is normalized from
  `nil` to an empty map so that the returned token remains a valid
  Context.
  """
  @spec attach(ctx :: t()) :: token()
  def attach(ctx) do
    Process.put(@current_key, ctx) || %{}
  end

  @doc """
  **OTel API (optional global)** — "Detach Context"
  (`context/README.md` L119-L136).

  Restores the previous Context from a token returned by `attach/1`.
  Returns `:ok`.

  Per spec L124-L129 an implementation MAY detect wrong-order detach
  calls and emit a signal; this implementation does not, matching the
  reference Erlang behaviour.
  """
  @spec detach(token :: token()) :: :ok
  def detach(token) do
    Process.put(@current_key, token)
    :ok
  end

  @doc """
  **Local helper** (not in spec).

  Reads through the current process Context. Equivalent to
  `get_value(current(), key)`. Returns `nil` when the key is absent;
  compose `|| default` for fallback.
  """
  @spec get_value(key :: key()) :: value()
  def get_value(key), do: get_value(current(), key)

  @doc """
  **Local helper** (not in spec).

  Writes through the current process Context. Equivalent to
  `current() |> set_value(key, value) |> attach()`. Returns `:ok`.
  """
  @spec set_value(key :: key(), value :: value()) :: :ok
  def set_value(key, value) do
    current()
    |> set_value(key, value)
    |> attach()

    :ok
  end
end
