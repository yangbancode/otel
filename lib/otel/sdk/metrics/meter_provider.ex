defmodule Otel.SDK.Metrics.MeterProvider do
  @moduledoc """
  SDK implementation of the `Otel.API.Metrics.MeterProvider`
  behaviour (`metrics/sdk.md` §MeterProvider L43-L155).

  A `GenServer` that owns metrics configuration (resource, views,
  readers) and creates meters. Registers itself as the global
  MeterProvider on start.

  All public functions are safe for concurrent use, satisfying
  spec `metrics/sdk.md` L1875-L1876 (Status: Stable) —
  *"MeterProvider — Meter creation, ForceFlush and Shutdown
  MUST be safe to be called concurrently."*

  ## Crash handling

  `init/1` enables `trap_exit` so a reader crash is delivered to
  the MeterProvider as `{:EXIT, pid, reason}` rather than
  propagating along the link. The dead reader is removed from
  the active list — graceful degradation, the other readers keep
  working. Once removed, the reader is **not** re-added; if its
  module is supervised by us, the MeterProvider's own crash
  takes its linked readers with it (no orphans). Mirrors the
  pattern in `Otel.SDK.Logs.LoggerProvider` and
  `Otel.SDK.Trace.TracerProvider`.

  ## Public API

  | Function | Role |
  |---|---|
  | `start_link/1` | **SDK** (lifecycle) |
  | `get_meter/2` | **SDK** (OTel API MUST) — `metrics/api.md` §Get a Meter |
  | `shutdown/2` | **SDK** (OTel API MUST) — `metrics/sdk.md` §Shutdown |
  | `force_flush/2` | **SDK** (OTel API MUST) — `metrics/sdk.md` §ForceFlush |
  | `add_view/3` | **SDK** (OTel API MUST) — `metrics/sdk.md` §View L259-L327 |

  ## References

  - OTel Metrics SDK §MeterProvider: `opentelemetry-specification/specification/metrics/sdk.md` L43-L155
  - OTel Metrics API §MeterProvider: `opentelemetry-specification/specification/metrics/api.md` L92-L156
  """

  require Logger

  use GenServer
  @behaviour Otel.API.Metrics.MeterProvider

  @type config :: %{
          resource: Otel.SDK.Resource.t(),
          views: [Otel.SDK.Metrics.View.t()],
          readers: [{module(), Otel.SDK.Metrics.MetricReader.config()}],
          exemplar_filter: Otel.SDK.Metrics.Exemplar.Filter.t()
        }

  # --- Client API ---

  @doc """
  **SDK** (lifecycle) — Starts the MeterProvider with the
  given configuration.
  """
  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    config = Keyword.get(opts, :config, %{})
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  **SDK** (OTel API MUST) — Get a Meter
  (`metrics/api.md` §Get a Meter).

  Falls back to the Noop meter if `server` is no longer alive.
  """
  @spec get_meter(
          server :: GenServer.server(),
          instrumentation_scope :: Otel.API.InstrumentationScope.t()
        ) ::
          Otel.API.Metrics.Meter.t()
  @impl Otel.API.Metrics.MeterProvider
  def get_meter(server, %Otel.API.InstrumentationScope{} = instrumentation_scope) do
    if GenServer.whereis(server) do
      GenServer.call(server, {:get_meter, instrumentation_scope})
    else
      {Otel.API.Metrics.Meter.Noop, []}
    end
  end

  @doc """
  **SDK** (OTel API MUST) — Shutdown
  (`metrics/sdk.md` §Shutdown).

  Invokes shutdown on all registered readers. After shutdown,
  `get_meter/2` returns the noop meter. Can only be called
  once; subsequent calls reply `{:error, :already_shutdown}`.
  """
  @spec shutdown(server :: GenServer.server(), timeout :: timeout()) :: :ok | {:error, term()}
  def shutdown(server, timeout \\ 5000) do
    if GenServer.whereis(server) do
      GenServer.call(server, :shutdown, timeout)
    else
      :ok
    end
  end

  @doc """
  **SDK** (OTel API MUST) — ForceFlush
  (`metrics/sdk.md` §ForceFlush).

  Forces all registered readers to collect and export metrics.
  """
  @spec force_flush(server :: GenServer.server(), timeout :: timeout()) :: :ok | {:error, term()}
  def force_flush(server, timeout \\ 5000) do
    if GenServer.whereis(server) do
      GenServer.call(server, :force_flush, timeout)
    else
      :ok
    end
  end

  @doc """
  **SDK** (introspection) — Returns the resource associated with
  this provider.
  """
  @spec resource(server :: GenServer.server()) :: Otel.SDK.Resource.t()
  def resource(server) do
    GenServer.call(server, :resource)
  end

  @doc """
  **SDK** (introspection) — Returns the current configuration
  snapshot.
  """
  @spec config(server :: GenServer.server()) :: config()
  def config(server) do
    GenServer.call(server, :config)
  end

  @doc """
  **SDK** (OTel API MUST) — Register a View
  (`metrics/sdk.md` §View L259-L327).

  Returns `{:error, reason}` if the View is invalid (e.g.
  wildcard name with stream name override).
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
    Process.flag(:trap_exit, true)

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

    observed_attrs_tab =
      :ets.new(:otel_observed_attrs, [
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    config =
      default_config()
      |> Map.merge(user_config)
      |> Map.put(:shut_down, false)
      |> Map.put(:instruments_tab, instruments_tab)
      |> Map.put(:streams_tab, streams_tab)
      |> Map.put(:metrics_tab, metrics_tab)
      |> Map.put(:callbacks_tab, callbacks_tab)
      |> Map.put(:exemplars_tab, exemplars_tab)
      |> Map.put(:observed_attrs_tab, observed_attrs_tab)

    base_meter_config = %{
      resource: config.resource,
      instruments_tab: instruments_tab,
      streams_tab: streams_tab,
      metrics_tab: metrics_tab,
      callbacks_tab: callbacks_tab,
      exemplars_tab: exemplars_tab,
      observed_attrs_tab: observed_attrs_tab,
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
  def handle_call({:get_meter, _instrumentation_scope}, _from, %{shut_down: true} = config) do
    {:reply, {Otel.API.Metrics.Meter.Noop, []}, config}
  end

  def handle_call(
        {:get_meter, %Otel.API.InstrumentationScope{} = instrumentation_scope},
        _from,
        config
      ) do
    warn_invalid_scope_name(instrumentation_scope)

    reader_configs = Map.get(config, :reader_configs, [{nil, %{}}])

    meter_config = %{
      scope: instrumentation_scope,
      resource: config.resource,
      instruments_tab: config.instruments_tab,
      streams_tab: config.streams_tab,
      metrics_tab: config.metrics_tab,
      callbacks_tab: config.callbacks_tab,
      exemplars_tab: config.exemplars_tab,
      observed_attrs_tab: config.observed_attrs_tab,
      views: config.views,
      exemplar_filter: config.exemplar_filter,
      reader_configs: reader_configs
    }

    meter = {Otel.SDK.Metrics.Meter, meter_config}
    {:reply, meter, config}
  end

  def handle_call(:shutdown, _from, %{shut_down: true} = config) do
    {:reply, {:error, :already_shutdown}, config}
  end

  def handle_call(:shutdown, _from, config) do
    result = invoke_all_readers(config.readers, :shutdown)
    {:reply, result, %{config | shut_down: true}}
  end

  def handle_call(:force_flush, _from, %{shut_down: true} = config) do
    {:reply, {:error, :already_shutdown}, config}
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

  @impl true
  def handle_info({:EXIT, _pid, _reason}, %{shut_down: true} = config) do
    # Already shutting down — ignore late EXIT signals from
    # readers we just terminated.
    {:noreply, config}
  end

  def handle_info({:EXIT, pid, reason}, config) do
    case Enum.find(config.readers, fn {_module, p} -> p == pid end) do
      nil ->
        # EXIT from a process we don't manage; ignore.
        {:noreply, config}

      {module, _pid} ->
        warn_reader_exited(module, pid, reason)
        new_readers = Enum.reject(config.readers, fn {_m, p} -> p == pid end)
        {:noreply, %{config | readers: new_readers}}
    end
  end

  # --- Private ---

  # Spec `metrics/api.md` §Get a Meter — *"In the case where an
  # invalid `name` (null or empty string) is specified, a working
  # `Meter` MUST be returned as a fallback rather than returning
  # null or throwing an exception, its `name` SHOULD keep the
  # original invalid value, and a message reporting that the
  # specified value is invalid SHOULD be logged."* The MUST is
  # satisfied structurally — we always return the SDK Meter; the
  # SHOULD log is enforced here.
  @spec warn_invalid_scope_name(scope :: Otel.API.InstrumentationScope.t()) :: :ok
  defp warn_invalid_scope_name(%Otel.API.InstrumentationScope{name: ""}) do
    Logger.warning(
      "Otel.SDK.Metrics.MeterProvider: invalid Meter name (empty string) — returning a working Meter as fallback"
    )

    :ok
  end

  defp warn_invalid_scope_name(_scope), do: :ok

  # Emitted from `handle_info({:EXIT, ...})` when a managed
  # MetricReader crashes. Not in spec — operational signal.
  @spec warn_reader_exited(module :: module(), pid :: pid(), reason :: term()) :: :ok
  defp warn_reader_exited(module, pid, reason) do
    Logger.warning(
      "Otel.SDK.Metrics.MeterProvider: MetricReader #{inspect(module)} " <>
        "(#{inspect(pid)}) exited with #{inspect(reason)} — removed from active list"
    )

    :ok
  end

  @spec default_config() :: config()
  defp default_config do
    %{
      resource: Otel.SDK.Resource.default(),
      views: [],
      readers: [],
      exemplar_filter: :trace_based
    }
  end

  @spec start_readers(
          readers :: [{module(), Otel.SDK.Metrics.MetricReader.config()}],
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
