defmodule Otel.SDK.Logs.LoggerProvider do
  @moduledoc """
  SDK implementation of the LoggerProvider.

  A `GenServer` that owns log configuration (resource, processors)
  and creates loggers. Registers itself as the global LoggerProvider
  on start.

  All public functions are safe for concurrent use.
  """

  use GenServer

  @type config :: %{
          resource: Otel.SDK.Resource.t(),
          processors: [{module(), map()}]
        }

  # --- Client API ---

  @doc """
  Starts the LoggerProvider with the given configuration.
  """
  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {config, server_opts} = Keyword.pop(opts, :config, %{})
    GenServer.start_link(__MODULE__, config, server_opts)
  end

  @doc """
  Returns a logger for the given instrumentation scope.
  """
  @spec get_logger(
          server :: GenServer.server(),
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil
        ) ::
          Otel.API.Logs.Logger.t()
  def get_logger(server, name, version \\ "", schema_url \\ nil) do
    GenServer.call(server, {:get_logger, name, version, schema_url})
  end

  @doc """
  Returns the resource associated with this provider.
  """
  @spec resource(server :: GenServer.server()) :: Otel.SDK.Resource.t()
  def resource(server) do
    GenServer.call(server, :resource)
  end

  @doc """
  Returns the current configuration.
  """
  @spec config(server :: GenServer.server()) :: config()
  def config(server) do
    GenServer.call(server, :config)
  end

  @doc """
  Shuts down the LoggerProvider.

  Invokes shutdown on all registered processors. After shutdown,
  get_logger returns the noop logger. Can only be called once.
  """
  @spec shutdown(server :: GenServer.server(), timeout :: timeout()) :: :ok | {:error, term()}
  def shutdown(server, timeout \\ 5000) do
    GenServer.call(server, :shutdown, timeout)
  end

  @doc """
  Forces all registered processors to flush pending log records.
  """
  @spec force_flush(server :: GenServer.server(), timeout :: timeout()) :: :ok | {:error, term()}
  def force_flush(server, timeout \\ 5000) do
    GenServer.call(server, :force_flush, timeout)
  end

  # --- Server Callbacks ---

  @processors_key {__MODULE__, :processors}

  @impl true
  def init(user_config) do
    config =
      default_config()
      |> Map.merge(user_config)
      |> Map.put(:shut_down, false)

    :persistent_term.put(@processors_key, config.processors)

    Otel.API.Logs.LoggerProvider.set_provider(__MODULE__)
    {:ok, config}
  end

  @impl true
  def handle_call({:get_logger, _name, _version, _schema_url}, _from, %{shut_down: true} = config) do
    {:reply, {Otel.API.Logs.Logger.Noop, []}, config}
  end

  def handle_call({:get_logger, name, version, schema_url}, _from, config) do
    validated_name = validate_logger_name(name)

    scope = %Otel.API.InstrumentationScope{
      name: validated_name,
      version: version,
      schema_url: schema_url
    }

    logger_config = %{
      scope: scope,
      resource: config.resource,
      processors_key: @processors_key,
      log_record_limits: config.log_record_limits
    }

    logger = {Otel.SDK.Logs.Logger, logger_config}
    {:reply, logger, config}
  end

  def handle_call(:shutdown, _from, %{shut_down: true} = config) do
    {:reply, {:error, :already_shut_down}, config}
  end

  def handle_call(:shutdown, _from, config) do
    result = invoke_all_processors(config.processors, :shutdown)
    {:reply, result, %{config | shut_down: true}}
  end

  def handle_call(:force_flush, _from, %{shut_down: true} = config) do
    {:reply, {:error, :shut_down}, config}
  end

  def handle_call(:force_flush, _from, config) do
    result = invoke_all_processors(config.processors, :force_flush)
    {:reply, result, config}
  end

  def handle_call(:resource, _from, config) do
    {:reply, config.resource, config}
  end

  def handle_call(:config, _from, config) do
    {:reply, config, config}
  end

  # --- Private ---

  @spec validate_logger_name(name :: String.t() | nil) :: String.t()
  defp validate_logger_name(nil) do
    :logger.warning(
      "LoggerProvider: invalid logger name nil, using empty string",
      %{domain: [:otel, :logs]}
    )

    ""
  end

  defp validate_logger_name("") do
    :logger.warning(
      "LoggerProvider: invalid logger name (empty string)",
      %{domain: [:otel, :logs]}
    )

    ""
  end

  defp validate_logger_name(name) when is_binary(name), do: name

  @spec default_config() :: map()
  defp default_config do
    %{
      resource: Otel.SDK.Configuration.default_config().resource,
      processors: [],
      log_record_limits: %Otel.SDK.Logs.LogRecordLimits{}
    }
  end

  @spec invoke_all_processors(
          processors :: [{module(), map()}],
          function :: :shutdown | :force_flush
        ) :: :ok | {:error, [{module(), term()}]}
  defp invoke_all_processors(processors, function) do
    results =
      Enum.reduce(processors, [], fn {processor, processor_config}, errors ->
        case apply(processor, function, [processor_config]) do
          :ok -> errors
          {:error, reason} -> [{processor, reason} | errors]
        end
      end)

    case results do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end
end
