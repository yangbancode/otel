defmodule Otel.API.Logs.LoggerProvider do
  @moduledoc """
  Global LoggerProvider registration and Logger retrieval
  (OTel `logs/api.md` §LoggerProvider, L54-L97).

  Holds the process-wide pointer to the installed
  LoggerProvider implementation. When no SDK is installed,
  all operations resolve to the no-op logger
  (`Otel.API.Logs.Logger.Noop`).

  ## No API-level Logger cache

  `get_logger/1` does **not** cache the Logger it returns.
  Every call delegates to the registered provider's
  `get_logger/2` callback (or returns Noop if none). This
  avoids a bootstrap race: if an early `get_logger/1` is
  made before the SDK registers, a cached Noop would
  survive provider installation and silently drop every
  subsequent log.

  The spec's *"identical for identical parameters"*
  requirement (`logs/api.md` L94-L97) is still satisfied
  because SDK implementations return structurally-equal
  Logger tuples for equal scopes, and the Noop case is
  trivially `{Noop, []}` on every call.

  Performance: the API dispatches directly to the
  provider's `get_logger/2` on every call (or returns Noop
  when no provider is registered). SDK implementations that
  care about Logger-instance reuse should cache internally
  on their own `get_logger/2` path.

  ## Storage

  The global provider pointer lives in `:persistent_term`.
  The dispatch pattern (`{dispatcher_module, state}` tuple +
  `get_logger/2` callback) is shared across Trace, Metrics,
  and Logs.

  Unlike `Otel.Trace.Tracer.BehaviourProvider`,
  `opentelemetry-erlang` has **no** `otel_logger_provider.erl`
  equivalent — erlang routes Logs through OTP's built-in
  `:logger` module rather than exposing a dedicated API. This
  module fills that gap so the API surface stays uniform
  across the three signals.

  All functions are safe for concurrent use (spec L172-L173).

  ## Public API

  | Function | Role |
  |---|---|
  | `get_logger/0,1` | **Application** (OTel API MUST) — Get a Logger (L66-L97) |
  | `@callback get_logger/2` | **SDK** (OTel API MUST) — Dispatch callback (L66-L97) |
  | `get_provider/0` | **SDK** (installation hook) — access global provider (L58-L60) |
  | `set_provider/1` | **SDK** (installation hook) — register global provider (L58-L60) |

  ## References

  - OTel Logs API §LoggerProvider: `opentelemetry-specification/specification/logs/api.md` L54-L97
  - OTel Logs API §Concurrency: `opentelemetry-specification/specification/logs/api.md` L172-L173
  """

  @default_logger {Otel.API.Logs.Logger.Noop, []}

  @global_key {__MODULE__, :global}

  @typedoc """
  A `{dispatcher_module, state}` pair.

  The API layer treats the state as opaque; only
  `dispatcher_module` knows how to use it. This mirrors
  `Otel.API.Logs.Logger.t/0` and keeps the API decoupled from
  SDK internals (GenServer, Registry, etc.).

  `dispatcher_module` MUST implement the
  `Otel.API.Logs.LoggerProvider` behaviour.
  """
  @type t :: {module(), term()}

  # --- Application dispatch ---

  @doc """
  **Application** (OTel API MUST) — "Get a Logger"
  (`logs/api.md` L66-L97).

  Returns a Logger for the given instrumentation scope. Each
  call delegates to the registered provider's `get_logger/2`
  callback, or returns the noop logger when no provider is
  installed — no API-level cache, see the module's *"No
  API-level Logger cache"* section.

  The full `InstrumentationScope` struct (name, version,
  schema_url, attributes — spec L73-L93) is passed to the
  provider. Spec's "identical for identical parameters"
  (L95-L97) is satisfied by SDK-side structural equality.

  Without arguments, uses a default empty scope.
  """
  @spec get_logger(instrumentation_scope :: Otel.InstrumentationScope.t()) ::
          Otel.API.Logs.Logger.t()
  def get_logger(instrumentation_scope \\ %Otel.InstrumentationScope{})

  def get_logger(%Otel.InstrumentationScope{} = instrumentation_scope) do
    case get_provider() do
      nil ->
        @default_logger

      {module, state} ->
        module.get_logger(state, instrumentation_scope)
    end
  end

  # --- SDK callbacks ---

  @doc """
  **SDK** (OTel API MUST) — Dispatch callback invoked by
  `get_logger/1`.

  Implementations receive the opaque `state` they registered
  via `set_provider/1` along with the requested instrumentation
  scope, and return a Logger. The `get_logger/2` shape is the
  API↔SDK dispatch contract for §"Get a Logger"
  (`logs/api.md` L66-L97).
  """
  @callback get_logger(
              state :: term(),
              instrumentation_scope :: Otel.InstrumentationScope.t()
            ) :: Otel.API.Logs.Logger.t()

  # --- SDK installation hooks ---

  @doc """
  **SDK** (installation hook) — access the global
  LoggerProvider (`logs/api.md` L58-L60).

  > *"the API SHOULD provide a way to set/register and
  > access a global default `LoggerProvider`."*

  Returns the currently registered provider, or `nil` if
  none is registered.
  """
  @spec get_provider() :: t() | nil
  def get_provider do
    :persistent_term.get(@global_key, nil)
  end

  @doc """
  **SDK** (installation hook) — register the global
  LoggerProvider (`logs/api.md` L58-L60).

  > *"the API SHOULD provide a way to set/register and
  > access a global default `LoggerProvider`."*

  Registers the given `{module, state}` as the global
  LoggerProvider. The SDK LoggerProvider calls this from its
  `init/1` with `{__MODULE__, server_ref}`; `module` must
  implement the `Otel.API.Logs.LoggerProvider` behaviour.

  To clear the registration (e.g. in tests), use
  `:persistent_term.erase/1` directly.
  """
  @spec set_provider(provider :: t()) :: :ok
  def set_provider({_module, _state} = provider) do
    :persistent_term.put(@global_key, provider)
    :ok
  end
end
