defmodule Otel.SDK.Metrics.MeterProvider do
  @moduledoc """
  SDK implementation of the MeterProvider.

  A `GenServer` that owns metrics configuration (resource, views,
  readers) and creates meters. Registers itself as the global
  MeterProvider on start.

  All public functions are safe for concurrent use.
  """

  use GenServer

  @type config :: %{
          resource: Otel.SDK.Resource.t(),
          views: [term()],
          readers: [{module(), map()}]
        }

  # --- Client API ---

  @doc """
  Starts the MeterProvider with the given configuration.
  """
  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {config, server_opts} = Keyword.pop(opts, :config, %{})
    GenServer.start_link(__MODULE__, config, server_opts)
  end

  @doc """
  Returns a meter for the given instrumentation scope.
  """
  @spec get_meter(
          server :: GenServer.server(),
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil
        ) ::
          Otel.API.Metrics.Meter.t()
  def get_meter(server, name, version \\ "", schema_url \\ nil) do
    GenServer.call(server, {:get_meter, name, version, schema_url})
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
  Shuts down the MeterProvider.

  Invokes shutdown on all registered readers. After shutdown,
  get_meter returns the noop meter. Can only be called once.
  """
  @spec shutdown(server :: GenServer.server(), timeout :: timeout()) :: :ok | {:error, term()}
  def shutdown(server, timeout \\ 5000) do
    GenServer.call(server, :shutdown, timeout)
  end

  @doc """
  Forces all registered readers to collect and export metrics.
  """
  @spec force_flush(server :: GenServer.server(), timeout :: timeout()) :: :ok | {:error, term()}
  def force_flush(server, timeout \\ 5000) do
    GenServer.call(server, :force_flush, timeout)
  end

  # --- Server Callbacks ---

  @impl true
  def init(user_config) do
    instruments_tab =
      :ets.new(:otel_instruments, [:set, :public, read_concurrency: true, write_concurrency: true])

    config =
      default_config()
      |> Map.merge(user_config)
      |> Map.put(:shut_down, false)
      |> Map.put(:instruments_tab, instruments_tab)

    Otel.API.Metrics.MeterProvider.set_provider(__MODULE__)
    {:ok, config}
  end

  @impl true
  def handle_call({:get_meter, _name, _version, _schema_url}, _from, %{shut_down: true} = config) do
    {:reply, {Otel.API.Metrics.Meter.Noop, []}, config}
  end

  def handle_call({:get_meter, name, version, schema_url}, _from, config) do
    scope = %Otel.API.InstrumentationScope{
      name: name,
      version: version,
      schema_url: schema_url
    }

    meter_config = %{
      scope: scope,
      resource: config.resource,
      instruments_tab: config.instruments_tab
    }

    meter = {Otel.SDK.Metrics.Meter, meter_config}
    {:reply, meter, config}
  end

  def handle_call(:shutdown, _from, %{shut_down: true} = config) do
    {:reply, {:error, :already_shut_down}, config}
  end

  def handle_call(:shutdown, _from, config) do
    result = invoke_all_readers(config.readers, :shutdown)
    {:reply, result, %{config | shut_down: true}}
  end

  def handle_call(:force_flush, _from, %{shut_down: true} = config) do
    {:reply, {:error, :shut_down}, config}
  end

  def handle_call(:force_flush, _from, config) do
    result = invoke_all_readers(config.readers, :force_flush)
    {:reply, result, config}
  end

  def handle_call(:resource, _from, config) do
    {:reply, config.resource, config}
  end

  def handle_call(:config, _from, config) do
    {:reply, config, config}
  end

  # --- Private ---

  @spec default_config() :: map()
  defp default_config do
    %{
      resource: Otel.SDK.Configuration.default_config().resource,
      views: [],
      readers: []
    }
  end

  @spec invoke_all_readers(
          readers :: [{module(), map()}],
          function :: :shutdown | :force_flush
        ) :: :ok | {:error, [{module(), term()}]}
  defp invoke_all_readers(readers, function) do
    results =
      Enum.reduce(readers, [], fn {reader, reader_config}, errors ->
        case apply(reader, function, [reader_config]) do
          :ok -> errors
          {:error, reason} -> [{reader, reason} | errors]
        end
      end)

    case results do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end
end
