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
  Returns the global LoggerProvider module, or `nil` if none is set.
  """
  @spec get_provider() :: module() | nil
  def get_provider do
    :persistent_term.get(@provider_key, nil)
  end

  @doc """
  Sets the global LoggerProvider module.
  """
  @spec set_provider(provider :: module()) :: :ok
  def set_provider(provider) when is_atom(provider) do
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
          attributes :: map()
        ) :: Otel.API.Logs.Logger.t()
  def get_logger(name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    name = validate_name(name)
    key = {@logger_key_prefix, {name, version, schema_url}}

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
          attributes :: map()
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
          attributes :: map()
        ) :: Otel.API.Logs.Logger.t()
  defp fetch_or_default(_name, _version, _schema_url, _attributes) do
    @default_logger
  end
end
