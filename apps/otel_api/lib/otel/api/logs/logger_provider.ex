defmodule Otel.API.Logs.LoggerProvider do
  @moduledoc """
  Global LoggerProvider registration and Logger retrieval
  (OTel `logs/api.md` §LoggerProvider, L54-L97).

  Holds the process-wide pointer to the installed
  LoggerProvider implementation and caches the `Logger`
  instances it returns. When no SDK is installed, all
  operations resolve to the no-op logger
  (`Otel.API.Logs.Logger.Noop`).

  ## Storage

  Both the global provider pointer and the scope-keyed logger
  cache live in `:persistent_term`. The dispatch pattern
  (`{dispatcher_module, state}` tuple + `get_logger/2`
  callback) is shared across Trace, Metrics, and Logs.

  Unlike `Otel.API.Trace.TracerProvider`,
  `opentelemetry-erlang` has **no** `otel_logger_provider.erl`
  equivalent — erlang routes Logs through OTP's built-in
  `:logger` module rather than exposing a dedicated API. This
  module fills that gap so the API surface stays uniform
  across the three signals.

  All functions are safe for concurrent use (spec L172-L173).

  ## Public API

  | Function | Role |
  |---|---|
  | `get_logger/0,1` | **OTel API MUST** (Get a Logger, L66-L97) |
  | `get_logger/2` (callback) | Internal dispatch contract (API ↔ SDK) |
  | `get_provider/0` | **OTel API SHOULD** — access global provider (L58-L60) |
  | `set_provider/1` | **OTel API SHOULD** — register global provider (L58-L60) |

  ## References

  - OTel Logs API §LoggerProvider: `opentelemetry-specification/specification/logs/api.md` L54-L97
  - OTel Logs API §Concurrency: `opentelemetry-specification/specification/logs/api.md` L172-L173
  """

  @default_logger {Otel.API.Logs.Logger.Noop, []}

  @global_key {__MODULE__, :global}
  @logger_key_prefix {__MODULE__, :logger}

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

  @doc """
  Dispatch callback invoked by `get_logger/1` on cache miss.

  Implementations receive the opaque `state` they registered
  via `set_provider/1` along with the requested instrumentation
  scope, and return the Logger to cache. Not part of the OTel
  spec — this is the internal dispatch contract between the
  API and SDK layers.
  """
  @callback get_logger(
              state :: term(),
              instrumentation_scope :: Otel.API.InstrumentationScope.t()
            ) :: Otel.API.Logs.Logger.t()

  @doc """
  **OTel API MUST** — "Get a Logger" (`logs/api.md` L66-L97).

  Returns a Logger for the given instrumentation scope. On
  cache miss delegates to the registered provider's
  `get_logger/2` callback, or returns the noop logger when no
  provider is installed. Subsequent calls with an equal scope
  return the cached logger.

  The full `InstrumentationScope` struct (name, version,
  schema_url, attributes — spec L73-L93) is the cache key, so
  "identical" and "distinct" loggers (L95-L97) are
  distinguished automatically by map equality.

  Without arguments, uses a default empty scope.
  """
  @spec get_logger(instrumentation_scope :: Otel.API.InstrumentationScope.t()) ::
          Otel.API.Logs.Logger.t()
  def get_logger(instrumentation_scope \\ %Otel.API.InstrumentationScope{})

  def get_logger(%Otel.API.InstrumentationScope{} = instrumentation_scope) do
    key = {@logger_key_prefix, instrumentation_scope}

    case :persistent_term.get(key, nil) do
      nil ->
        logger = fetch_or_default(instrumentation_scope)
        :persistent_term.put(key, logger)
        logger

      logger ->
        logger
    end
  end

  @doc """
  **OTel API SHOULD** — access the global LoggerProvider
  (`logs/api.md` L58-L60).

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
  **OTel API SHOULD** — register the global LoggerProvider
  (`logs/api.md` L58-L60).

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

  @spec fetch_or_default(instrumentation_scope :: Otel.API.InstrumentationScope.t()) ::
          Otel.API.Logs.Logger.t()
  defp fetch_or_default(%Otel.API.InstrumentationScope{} = instrumentation_scope) do
    case get_provider() do
      nil ->
        @default_logger

      {module, state} ->
        module.get_logger(state, instrumentation_scope)
    end
  end
end
