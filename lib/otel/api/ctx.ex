defmodule Otel.API.Ctx do
  @moduledoc """
  OTel Context (spec `context/README.md`, Status: **Stable**).

  A propagation mechanism that carries execution-scoped values across
  API boundaries within a single process. Cross-cutting concerns
  (Trace, Baggage, …) store their values in the Context.

  The Context type `t/0` is `@opaque` — construct via `new/0` and
  read/write only through the public API. The three spec-mandated
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
  | `create_key/1`, `get_value/2`, `set_value/3` | **Application** (OTel API MUST) — core Context ops (L56-L92) |
  | `current/0`, `attach/1`, `detach/1` | **Application** (OTel API SHOULD) — optional global ops (L95-L136) |
  | `new/0` | **Application** (Convenience) — build an empty Context |

  ## References

  - OTel Context: `opentelemetry-specification/specification/context/README.md`
  """

  @typedoc """
  An opaque OTel Context (spec `context/README.md` §Overview).

  The internal representation (a plain Elixir map) is not part of the
  public contract — construct with `new/0` and access only through the
  public API. Per spec "A Context MUST be immutable, and its write
  operations MUST result in the creation of a new Context";
  `set_value/3` returns a new Context and leaves the input unchanged.

  `attach/1` returns a value of this type that serves as the **Token**
  per spec L113 — pass it to `detach/1` to restore the previous
  Context. Treat attach-returned values as opaque tokens; do not
  inspect their contents.
  """
  @opaque t :: map()

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

  @current_key {__MODULE__, :current}

  @doc """
  **Application** (OTel API MUST) — "Create a key"
  (`context/README.md` L56-L67).

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
  **Application** (OTel API MUST) — "Get value"
  (`context/README.md` L69-L79).

  Returns the value in `ctx` for `key`, or `nil` when the key is not
  present. Callers who want a default value compose
  `|| default` at the call site.
  """
  @spec get_value(ctx :: t(), key :: key()) :: value()
  def get_value(ctx, key), do: Map.get(ctx, key)

  @doc """
  **Application** (OTel API MUST) — "Set value"
  (`context/README.md` L81-L92).

  Returns a new Context with `key` mapped to `value`. The spec
  requires immutability — the input `ctx` is unchanged.
  """
  @spec set_value(ctx :: t(), key :: key(), value :: value()) :: t()
  def set_value(ctx, key, value), do: Map.put(ctx, key, value)

  @doc """
  **Application** (OTel API SHOULD) — "Get current Context"
  (`context/README.md` L101-L103, optional global operation).

  Returns the current process's Context, or a fresh empty Context
  when nothing is attached. Used by SDK components and instrumentation
  libraries to read the ambient Context. End-user code typically reads
  domain values through higher-level APIs
  (`Otel.API.Baggage.current/0`, `Otel.API.Trace.current_span/0`)
  rather than calling this directly.
  """
  @spec current() :: t()
  def current do
    Process.get(@current_key) || %{}
  end

  @doc """
  **Application** (OTel API SHOULD) — "Attach Context"
  (`context/README.md` L105-L117, optional global operation).

  Associates `ctx` with the current process and returns the previous
  Context, which can be passed to `detach/1` as a token per spec L113.
  On the first attach in a process, the previous Context is normalized
  from `nil` to an empty Context so that the returned token is always
  a valid Context value.

  Treat the returned value as an opaque token — do not inspect it.
  """
  @spec attach(ctx :: t()) :: t()
  def attach(ctx) do
    Process.put(@current_key, ctx) || %{}
  end

  @doc """
  **Application** (OTel API SHOULD) — "Detach Context"
  (`context/README.md` L119-L136, optional global operation).

  Restores the previous Context from a token returned by `attach/1`.
  Returns `:ok`.

  Per spec L124-L129 an implementation MAY detect wrong-order detach
  calls and emit a signal. This implementation does not — the clause
  is a spec MAY (optional), and
  `.claude/rules/code-conventions.md` §No SHOULD-level diagnostics
  directs us to skip diagnostic emissions that the spec does not
  mandate. `opentelemetry-erlang` happens to take the same
  approach.
  """
  @spec detach(ctx :: t()) :: :ok
  def detach(ctx) do
    Process.put(@current_key, ctx)
    :ok
  end

  @doc """
  **Application** (Convenience) — build an empty Context.

  Returns a fresh empty Context. Preferred over `%{}` at external
  call sites because `t/0` is opaque.
  """
  @spec new() :: t()
  def new, do: %{}

  # Internal: cross-module helper used by `Otel.API.Baggage` and
  # `Otel.API.Trace` to read a value through the implicit
  # process-local current Context. Equivalent to
  # `get_value(current(), key)`.
  @doc false
  @spec get_value(key :: key()) :: value()
  def get_value(key), do: get_value(current(), key)

  # Internal: cross-module helper used by `Otel.API.Baggage` and
  # `Otel.API.Trace` to write a value through the implicit
  # process-local current Context. Equivalent to
  # `current() |> set_value(key, value) |> attach()`.
  @doc false
  @spec set_value(key :: key(), value :: value()) :: :ok
  def set_value(key, value) do
    current()
    |> set_value(key, value)
    |> attach()

    :ok
  end
end
