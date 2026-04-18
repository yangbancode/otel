defmodule Otel.API.Logs.LoggerProvider do
  @moduledoc """
  Global LoggerProvider registration and Logger retrieval.

  Uses `persistent_term` for storage, matching the TracerProvider
  and MeterProvider pattern. When no SDK is installed, all
  operations return no-op loggers.

  All functions are safe for concurrent use.
  """

  require Logger

  @default_logger {Otel.API.Logs.Logger.Noop, []}

  @provider_key {__MODULE__, :global}
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
              name :: String.t(),
              version :: String.t(),
              schema_url :: String.t() | nil,
              attributes :: Otel.API.Attribute.attributes()
            ) :: Otel.API.Logs.Logger.t()

  @doc """
  Returns the global LoggerProvider, or `nil` if none is set.
  """
  @spec get_provider() :: t() | nil
  def get_provider do
    :persistent_term.get(@provider_key, nil)
  end

  @doc """
  Sets the global LoggerProvider.

  Accepts a `{module, state}` tuple. The SDK LoggerProvider calls this
  from its `init/1` with `{__MODULE__, server_ref}`. `nil` clears the
  registration.
  """
  @spec set_provider(provider :: t() | nil) :: :ok
  def set_provider({module, _state} = provider) when is_atom(module) do
    :persistent_term.put(@provider_key, provider)
    :ok
  end

  def set_provider(nil) do
    :persistent_term.put(@provider_key, nil)
    :ok
  end

  @doc """
  Returns a Logger for the given instrumentation scope.

  Invalid name (nil or empty) returns a working Logger with empty
  name and logs a warning. Loggers are cached in `persistent_term`.
  """
  @spec get_logger(
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: Otel.API.Attribute.attributes()
        ) :: Otel.API.Logs.Logger.t()
  def get_logger(name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    name = validate_name(name)
    key = {@logger_key_prefix, {name, version, schema_url, attributes}}

    case :persistent_term.get(key, nil) do
      nil ->
        logger = fetch_or_default(name, version, schema_url, attributes)
        :persistent_term.put(key, logger)
        logger

      logger ->
        logger
    end
  end

  @doc """
  Returns the InstrumentationScope for a logger obtained with the
  given parameters.
  """
  @spec scope(
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: Otel.API.Attribute.attributes()
        ) ::
          Otel.API.InstrumentationScope.t()
  def scope(name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    %Otel.API.InstrumentationScope{
      name: name,
      version: version,
      schema_url: schema_url,
      attributes: attributes
    }
  end

  @spec validate_name(name :: String.t() | nil) :: String.t()
  defp validate_name(nil) do
    # Log only when an SDK is registered. Without a provider, the Noop spec
    # (logs/noop.md L33-35) mandates no log output for any operation.
    if get_provider() != nil do
      Logger.warning("invalid logger name nil, using empty string")
    end

    ""
  end

  defp validate_name("") do
    if get_provider() != nil do
      Logger.warning("invalid logger name (empty string), using empty string")
    end

    ""
  end

  defp validate_name(name) when is_binary(name), do: name

  @spec fetch_or_default(
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: Otel.API.Attribute.attributes()
        ) :: Otel.API.Logs.Logger.t()
  defp fetch_or_default(name, version, schema_url, attributes) do
    case get_provider() do
      nil ->
        @default_logger

      {module, state} ->
        module.get_logger(state, name, version, schema_url, attributes)
    end
  end
end
