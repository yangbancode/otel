defmodule Otel.SDK.Logs.LoggerProvider do
  @moduledoc """
  SDK implementation of the LoggerProvider.

  A `GenServer` that owns log configuration (resource, processors)
  and creates loggers. Registers itself as the global LoggerProvider
  on start.

  All public functions are safe for concurrent use.

  ## Processor monitoring

  When a registered processor's callback config carries enough
  information to identify the processor's process (`:reg_name`
  or `:pid`), the LoggerProvider monitors that process at start
  via `Process.monitor/1`. If the process dies, the
  LoggerProvider receives `{:DOWN, ...}` and removes the
  processor from its dispatch list (and from the
  `:persistent_term` fast path used by `Logger.emit`).

  This is graceful degradation: a single processor's death does
  not propagate to the LoggerProvider or its other registered
  processors. Once removed, the processor is **not** re-added,
  even if a supervisor restarts the underlying process — the
  LoggerProvider holds no PID for the new instance. Re-adding
  is the application's explicit choice (no public API for it
  yet).

  Module-only processors (callback config carries no
  identifiable process — typical for in-test fixtures) are
  registered without monitoring; they have no process to die.

  Mirrors the pattern used by erlang
  `otel_meter_server.erl:369` for monitored readers.
  """

  use GenServer
  @behaviour Otel.API.Logs.LoggerProvider

  @typedoc """
  A registered processor in the provider state.

  - `:module` — the `LogRecordProcessor` implementation
  - `:config` — the user-supplied callback config (passed to
    every processor callback verbatim)
  - `:monitor_ref` — `Process.monitor/1` reference, or `nil`
    for module-only processors that expose no process to monitor
  """
  @type processor_entry :: %{
          module: module(),
          config: Otel.SDK.Logs.LogRecordProcessor.config(),
          monitor_ref: reference() | nil
        }

  @type config :: %{
          resource: Otel.SDK.Resource.t(),
          processors: [processor_entry()],
          log_record_limits: Otel.SDK.Logs.LogRecordLimits.t()
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

  Falls back to the Noop logger if `server` is no longer alive.
  """
  @spec get_logger(
          server :: GenServer.server(),
          instrumentation_scope :: Otel.API.InstrumentationScope.t()
        ) ::
          Otel.API.Logs.Logger.t()
  @impl Otel.API.Logs.LoggerProvider
  def get_logger(server, %Otel.API.InstrumentationScope{} = instrumentation_scope) do
    if alive?(server) do
      GenServer.call(server, {:get_logger, instrumentation_scope})
    else
      {Otel.API.Logs.Logger.Noop, []}
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

  @impl true
  def init(user_config) do
    processors_key = {__MODULE__, :processors, make_ref()}

    base = Map.merge(default_config(), user_config)

    monitored = Enum.map(Map.get(base, :processors, []), &monitor_processor/1)

    config =
      base
      |> Map.put(:processors, monitored)
      |> Map.put(:shut_down, false)
      |> Map.put(:processors_key, processors_key)

    :persistent_term.put(processors_key, project_processors(monitored))

    Otel.API.Logs.LoggerProvider.set_provider({__MODULE__, self_ref()})
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
  def handle_call({:get_logger, _instrumentation_scope}, _from, %{shut_down: true} = config) do
    {:reply, {Otel.API.Logs.Logger.Noop, []}, config}
  end

  def handle_call(
        {:get_logger, %Otel.API.InstrumentationScope{} = instrumentation_scope},
        _from,
        config
      ) do
    logger_config = %{
      scope: instrumentation_scope,
      resource: config.resource,
      processors_key: config.processors_key,
      log_record_limits: config.log_record_limits
    }

    logger = {Otel.SDK.Logs.Logger, logger_config}
    {:reply, logger, config}
  end

  def handle_call(:shutdown, _from, %{shut_down: true} = config) do
    {:reply, {:error, :already_shut_down}, config}
  end

  def handle_call(:shutdown, _from, config) do
    # Demonitor (and flush any queued :DOWN) before invoking each
    # processor's shutdown — we initiate the deaths here, so the
    # resulting :DOWN messages would only be noise.
    Enum.each(config.processors, &demonitor_processor/1)

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

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{shut_down: true} = config) do
    # Already shutting down — ignore late-arriving DOWN.
    {:noreply, config}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, config) do
    new_processors = Enum.reject(config.processors, &(&1.monitor_ref == ref))

    # Update the persistent_term fast path so `Logger.emit` stops
    # dispatching to the dead processor immediately.
    :persistent_term.put(config.processors_key, project_processors(new_processors))

    {:noreply, %{config | processors: new_processors}}
  end

  # --- Private ---

  @spec default_config() :: %{atom() => term()}
  defp default_config do
    %{
      resource: Otel.SDK.Resource.default(),
      processors: [],
      log_record_limits: %Otel.SDK.Logs.LogRecordLimits{}
    }
  end

  @spec monitor_processor({module(), Otel.SDK.Logs.LogRecordProcessor.config()}) ::
          processor_entry()
  defp monitor_processor({module, callback_config}) do
    %{
      module: module,
      config: callback_config,
      monitor_ref: monitor_if_resolvable(callback_config)
    }
  end

  @spec monitor_if_resolvable(Otel.SDK.Logs.LogRecordProcessor.config()) :: reference() | nil
  defp monitor_if_resolvable(callback_config) do
    case resolve_pid(callback_config) do
      nil -> nil
      pid -> Process.monitor(pid)
    end
  end

  @spec resolve_pid(Otel.SDK.Logs.LogRecordProcessor.config()) :: pid() | nil
  defp resolve_pid(%{pid: pid}) when is_pid(pid), do: pid

  defp resolve_pid(%{reg_name: name}) when is_atom(name) do
    case Process.whereis(name) do
      nil ->
        raise ArgumentError,
              "LogRecordProcessor :reg_name #{inspect(name)} is not registered. " <>
                "Start the processor before LoggerProvider."

      pid ->
        pid
    end
  end

  defp resolve_pid(_), do: nil

  @spec demonitor_processor(processor_entry()) :: :ok
  defp demonitor_processor(%{monitor_ref: nil}), do: :ok

  defp demonitor_processor(%{monitor_ref: ref}) do
    Process.demonitor(ref, [:flush])
    :ok
  end

  @spec project_processors([processor_entry()]) ::
          [{module(), Otel.SDK.Logs.LogRecordProcessor.config()}]
  defp project_processors(processors) do
    Enum.map(processors, fn %{module: m, config: c} -> {m, c} end)
  end

  @spec invoke_all_processors(
          processors :: [processor_entry()],
          function :: :shutdown | :force_flush
        ) :: :ok | {:error, [{module(), term()}]}
  defp invoke_all_processors(processors, function) do
    results =
      Enum.reduce(processors, [], fn %{module: module, config: callback_config}, errors ->
        case apply(module, function, [callback_config]) do
          :ok -> errors
          {:error, reason} -> [{module, reason} | errors]
        end
      end)

    case results do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end
end
