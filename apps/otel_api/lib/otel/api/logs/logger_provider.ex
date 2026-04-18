defmodule Otel.API.Logs.LoggerProvider do
  @moduledoc """
  Global LoggerProvider registration and Logger retrieval.

  Uses `persistent_term` for storage, matching the TracerProvider
  and MeterProvider pattern. When no SDK is installed, all
  operations return no-op loggers.

  All functions are safe for concurrent use.
  """

  @default_logger {Otel.API.Logs.Logger.Noop, []}

  @provider_key {__MODULE__, :global}
  @logger_key_prefix {__MODULE__, :logger}

  @doc """
  Returns the global LoggerProvider, or `nil` if none is set.

  The provider is a pid or a registered name pointing to the SDK
  LoggerProvider GenServer.
  """
  @spec get_provider() :: GenServer.server() | nil
  def get_provider do
    :persistent_term.get(@provider_key, nil)
  end

  @doc """
  Sets the global LoggerProvider.

  Accepts a pid or a registered name (module atom). The SDK
  LoggerProvider calls this from its `init/1` with `self()`.
  """
  @spec set_provider(provider :: GenServer.server() | nil) :: :ok
  def set_provider(provider) when is_atom(provider) or is_pid(provider) do
    :persistent_term.put(@provider_key, provider)
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
    :logger.warning(
      "LoggerProvider: invalid logger name nil, using empty string",
      %{domain: [:otel, :logs]}
    )

    ""
  end

  defp validate_name("") do
    :logger.warning(
      "LoggerProvider: invalid logger name (empty string)",
      %{domain: [:otel, :logs]}
    )

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

      provider ->
        if provider_alive?(provider) do
          GenServer.call(provider, {:get_logger, name, version, schema_url, attributes})
        else
          @default_logger
        end
    end
  end

  @spec provider_alive?(provider :: GenServer.server()) :: boolean()
  defp provider_alive?(pid) when is_pid(pid), do: Process.alive?(pid)
  defp provider_alive?(name) when is_atom(name), do: Process.whereis(name) != nil
end
