defmodule Otel.API.Logs.LoggerProvider do
  @moduledoc """
  Global LoggerProvider registration and Logger retrieval.

  Uses `persistent_term` for storage, matching the TracerProvider
  and MeterProvider pattern. When no SDK is installed, all
  operations return no-op loggers.

  All functions are safe for concurrent use.
  """

  @default_logger {Otel.API.Logs.Logger.Noop, []}

  @global_key {__MODULE__, :global}
  @logger_key_prefix {__MODULE__, :logger}

  @typedoc """
  A `{dispatcher_module, state}` pair.

  The API layer treats the state as opaque; only `dispatcher_module`
  knows how to use it. This mirrors `Otel.API.Logs.Logger.t/0` and
  keeps the API decoupled from SDK internals.

  `dispatcher_module` MUST implement the `Otel.API.Logs.LoggerProvider`
  behaviour.
  """
  @type t :: {module(), term()}

  @doc """
  Returns a logger for the given instrumentation scope.

  Called by the API layer when no cached logger matches the scope.
  Implementations receive the opaque `state` they registered via
  `set_provider/1`.
  """
  @callback get_logger(
              state :: term(),
              instrumentation_scope :: Otel.API.InstrumentationScope.t()
            ) :: Otel.API.Logs.Logger.t()

  @doc """
  Returns the global LoggerProvider, or `nil` if none is set.
  """
  @spec get_provider() :: t() | nil
  def get_provider do
    :persistent_term.get(@global_key, nil)
  end

  @doc """
  Sets the global LoggerProvider.

  Accepts a `{module, state}` tuple. The SDK LoggerProvider calls this
  from its `init/1` with `{__MODULE__, server_ref}`. `nil` clears the
  registration.
  """
  @spec set_provider(provider :: t() | nil) :: :ok
  def set_provider({module, _state} = provider) when is_atom(module) do
    :persistent_term.put(@global_key, provider)
    :ok
  end

  def set_provider(nil) do
    :persistent_term.put(@global_key, nil)
    :ok
  end

  @doc """
  Returns a Logger for the given instrumentation scope.

  Accepts an `Otel.API.InstrumentationScope` struct. Without arguments,
  uses a default empty scope. Loggers are cached in `persistent_term`
  keyed by the scope value.
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
