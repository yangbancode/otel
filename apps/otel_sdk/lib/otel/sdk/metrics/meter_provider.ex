defmodule Otel.SDK.Metrics.MeterProvider do
  @moduledoc """
  SDK implementation of the MeterProvider.

  A `GenServer` that owns metrics configuration (resource, views,
  readers) and creates meters. Registers itself as the global
  MeterProvider on start.

  All public functions are safe for concurrent use.
  """

  use GenServer
  @behaviour Otel.API.Metrics.MeterProvider

  @type config :: %{
          resource: Otel.SDK.Resource.t(),
          views: [Otel.SDK.Metrics.View.t()],
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

  Falls back to the Noop meter if `server` is no longer alive.
  """
  @spec get_meter(
          server :: GenServer.server(),
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: Otel.API.Attribute.attributes()
        ) ::
          Otel.API.Metrics.Meter.t()
  @impl Otel.API.Metrics.MeterProvider
  def get_meter(server, name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    if alive?(server) do
      GenServer.call(server, {:get_meter, name, version, schema_url, attributes})
    else
      {Otel.API.Metrics.Meter.Noop, []}
    end
  end

  @spec alive?(server :: GenServer.server()) :: boolean()
  defp alive?(pid) when is_pid(pid), do: Process.alive?(pid)
  defp alive?(name) when is_atom(name), do: Process.whereis(name) != nil

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

  @doc """
  Registers a View with the MeterProvider.

  Returns `{:error, reason}` if the View is invalid (e.g. wildcard
  name with stream name override).
  """
  @spec add_view(
          server :: GenServer.server(),
          criteria :: Otel.SDK.Metrics.View.criteria(),
          config :: Otel.SDK.Metrics.View.config()
        ) :: :ok | {:error, String.t()}
  def add_view(server, criteria \\ %{}, config \\ %{}) do
    GenServer.call(server, {:add_view, criteria, config})
  end

  # --- Server Callbacks ---

  @impl true
  def init(user_config) do
    instruments_tab =
      :ets.new(:otel_instruments, [:set, :public, read_concurrency: true, write_concurrency: true])

    streams_tab =
      :ets.new(:otel_streams, [:bag, :public, read_concurrency: true, write_concurrency: true])

    metrics_tab =
      :ets.new(:otel_metrics, [:set, :public, read_concurrency: true, write_concurrency: true])

    callbacks_tab =
      :ets.new(:otel_callbacks, [:bag, :public, read_concurrency: true, write_concurrency: true])

    exemplars_tab =
      :ets.new(:otel_exemplars, [:set, :public, read_concurrency: true, write_concurrency: true])

    config =
      default_config()
      |> Map.merge(user_config)
      |> Map.put(:shut_down, false)
      |> Map.put(:instruments_tab, instruments_tab)
      |> Map.put(:streams_tab, streams_tab)
      |> Map.put(:metrics_tab, metrics_tab)
      |> Map.put(:callbacks_tab, callbacks_tab)
      |> Map.put(:exemplars_tab, exemplars_tab)

    base_meter_config = %{
      resource: config.resource,
      instruments_tab: instruments_tab,
      streams_tab: streams_tab,
      metrics_tab: metrics_tab,
      callbacks_tab: callbacks_tab,
      exemplars_tab: exemplars_tab,
      exemplar_filter: config.exemplar_filter
    }

    {started_readers, reader_configs} = start_readers(config.readers, base_meter_config)
    config = Map.put(config, :readers, started_readers)
    config = Map.put(config, :reader_configs, reader_configs)

    Otel.API.Metrics.MeterProvider.set_provider({__MODULE__, self_ref()})
    {:ok, config}
  end

  @spec self_ref() :: atom() | pid()
  defp self_ref do
    case Process.info(self(), :registered_name) do
      {:registered_name, name} when is_atom(name) -> name
      _ -> self()
    end
  end

  @impl true
  def handle_call(
        {:get_meter, _name, _version, _schema_url, _attributes},
        _from,
        %{shut_down: true} = config
      ) do
    {:reply, {Otel.API.Metrics.Meter.Noop, []}, config}
  end

  def handle_call({:get_meter, name, version, schema_url, attributes}, _from, config) do
    scope = %Otel.API.InstrumentationScope{
      name: name,
      version: version,
      schema_url: schema_url,
      attributes: attributes
    }

    reader_configs = Map.get(config, :reader_configs, [{nil, %{}}])

    meter_config = %{
      scope: scope,
      resource: config.resource,
      instruments_tab: config.instruments_tab,
      streams_tab: config.streams_tab,
      metrics_tab: config.metrics_tab,
      callbacks_tab: config.callbacks_tab,
      exemplars_tab: config.exemplars_tab,
      views: config.views,
      exemplar_filter: config.exemplar_filter,
      reader_configs: reader_configs
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

  def handle_call({:add_view, criteria, view_config}, _from, config) do
    case Otel.SDK.Metrics.View.new(criteria, view_config) do
      {:ok, view} ->
        {:reply, :ok, %{config | views: config.views ++ [view]}}

      {:error, reason} ->
        {:reply, {:error, reason}, config}
    end
  end

  # --- Private ---

  @spec default_config() :: map()
  defp default_config do
    %{
      resource: Otel.SDK.Configuration.default_config().resource,
      views: [],
      readers: [],
      exemplar_filter: :trace_based
    }
  end

  @spec start_readers(
          readers :: [{module(), map()}],
          base_meter_config :: map()
        ) :: {[{module(), pid()}], [{reference() | nil, map()}]}
  defp start_readers([], base_meter_config) do
    reader_meter_config = Map.put(base_meter_config, :reader_id, nil)
    {[], [{nil, %{meter_config: reader_meter_config}}]}
  end

  defp start_readers(readers, base_meter_config) do
    {started, reader_configs} =
      Enum.reduce(readers, {[], []}, fn {reader_module, reader_config}, {started, configs} ->
        reader_id = make_ref()

        temporality_mapping =
          Map.get(
            reader_config,
            :temporality_mapping,
            Otel.API.Metrics.Instrument.default_temporality_mapping()
          )

        reader_opts = %{temporality_mapping: temporality_mapping}

        reader_meter_config =
          base_meter_config
          |> Map.put(:reader_id, reader_id)
          |> Map.put(:temporality_mapping, temporality_mapping)

        full_config = Map.put(reader_config, :meter_config, reader_meter_config)
        {:ok, pid} = reader_module.start_link(full_config)

        {
          [{reader_module, pid} | started],
          [{reader_id, reader_opts} | configs]
        }
      end)

    {Enum.reverse(started), Enum.reverse(reader_configs)}
  end

  @spec invoke_all_readers(
          readers :: [{module(), pid()}],
          function :: :shutdown | :force_flush
        ) :: :ok | {:error, [{module(), term()}]}
  defp invoke_all_readers(readers, function) do
    results =
      Enum.reduce(readers, [], fn {reader_module, reader_pid}, errors ->
        case apply(reader_module, function, [reader_pid]) do
          :ok -> errors
          {:error, reason} -> [{reader_module, reason} | errors]
        end
      end)

    case results do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end
end
