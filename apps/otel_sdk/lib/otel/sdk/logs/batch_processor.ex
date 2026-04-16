defmodule Otel.SDK.Logs.BatchProcessor do
  @moduledoc """
  BatchLogRecordProcessor that accumulates log records and exports
  in batches.

  Exports are triggered by a timer, queue size threshold, or
  force_flush. Uses a GenServer to serialize export calls (L534).
  """

  use GenServer

  @behaviour Otel.SDK.Logs.LogRecordProcessor

  @default_max_queue_size 2048
  @default_scheduled_delay_ms 1000
  @default_export_timeout_ms 30_000
  @default_max_export_batch_size 512

  # --- LogRecordProcessor callbacks ---

  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec on_emit(log_record :: map(), config :: Otel.SDK.Logs.LogRecordProcessor.config()) :: :ok
  def on_emit(log_record, %{reg_name: reg_name}) do
    GenServer.cast(reg_name, {:add_record, log_record})
    :ok
  end

  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec enabled?(opts :: keyword(), config :: Otel.SDK.Logs.LogRecordProcessor.config()) ::
          boolean()
  def enabled?(_opts, _config), do: true

  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec shutdown(config :: Otel.SDK.Logs.LogRecordProcessor.config()) :: :ok | {:error, term()}
  def shutdown(%{reg_name: reg_name}) do
    GenServer.call(reg_name, :shutdown)
  end

  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec force_flush(config :: Otel.SDK.Logs.LogRecordProcessor.config()) :: :ok | {:error, term()}
  def force_flush(%{reg_name: reg_name}) do
    GenServer.call(reg_name, :force_flush)
  end

  # --- GenServer ---

  @spec start_link(config :: map()) :: GenServer.on_start()
  def start_link(config) do
    name = Map.get(config, :name, __MODULE__)
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @impl GenServer
  @spec init(config :: map()) :: {:ok, map()}
  def init(config) do
    {exporter_module, exporter_opts} = Map.fetch!(config, :exporter)

    scheduled_delay =
      get_config(
        config,
        :scheduled_delay_ms,
        "OTEL_BLRP_SCHEDULE_DELAY",
        @default_scheduled_delay_ms
      )

    exporter =
      case exporter_module.init(exporter_opts) do
        {:ok, state} -> {exporter_module, state}
        :ignore -> nil
      end

    state = %{
      exporter: exporter,
      queue: [],
      queue_size: 0,
      max_queue_size:
        get_config(config, :max_queue_size, "OTEL_BLRP_MAX_QUEUE_SIZE", @default_max_queue_size),
      scheduled_delay_ms: scheduled_delay,
      export_timeout_ms:
        get_config(
          config,
          :export_timeout_ms,
          "OTEL_BLRP_EXPORT_TIMEOUT",
          @default_export_timeout_ms
        ),
      max_export_batch_size:
        get_config(
          config,
          :max_export_batch_size,
          "OTEL_BLRP_MAX_EXPORT_BATCH_SIZE",
          @default_max_export_batch_size
        ),
      shut_down: false
    }

    schedule_export(scheduled_delay)
    {:ok, state}
  end

  @spec get_config(config :: map(), key :: atom(), env_name :: String.t(), default :: integer()) ::
          integer()
  defp get_config(config, key, env_name, default) do
    Map.get(config, key) || parse_env_int(env_name, default)
  end

  @spec parse_env_int(env_name :: String.t(), default :: integer()) :: integer()
  defp parse_env_int(env_name, default) do
    case System.get_env(env_name) do
      nil ->
        default

      "" ->
        default

      value ->
        case Integer.parse(String.trim(value)) do
          {n, ""} -> n
          _ -> default
        end
    end
  end

  @impl GenServer
  @spec handle_cast(msg :: term(), state :: map()) :: {:noreply, map()}
  def handle_cast({:add_record, _log_record}, %{shut_down: true} = state) do
    {:noreply, state}
  end

  def handle_cast({:add_record, log_record}, state) do
    if state.queue_size >= state.max_queue_size do
      {:noreply, state}
    else
      new_state = %{state | queue: [log_record | state.queue], queue_size: state.queue_size + 1}

      if new_state.queue_size >= state.max_export_batch_size do
        {:noreply, do_export(new_state)}
      else
        {:noreply, new_state}
      end
    end
  end

  @impl GenServer
  @spec handle_call(msg :: term(), from :: GenServer.from(), state :: map()) ::
          {:reply, term(), map()}
  def handle_call(:force_flush, _from, %{shut_down: true} = state) do
    {:reply, {:error, :shut_down}, state}
  end

  def handle_call(:force_flush, _from, state) do
    {:reply, :ok, do_export(state)}
  end

  def handle_call(:shutdown, _from, %{shut_down: true} = state) do
    {:reply, {:error, :already_shut_down}, state}
  end

  def handle_call(:shutdown, _from, state) do
    new_state = do_export(state)

    case new_state.exporter do
      {module, exporter_state} -> module.shutdown(exporter_state)
      nil -> :ok
    end

    {:reply, :ok, %{new_state | exporter: nil, shut_down: true}}
  end

  @impl GenServer
  @spec handle_info(msg :: term(), state :: map()) :: {:noreply, map()}
  def handle_info(:export_timer, %{shut_down: true} = state) do
    {:noreply, state}
  end

  def handle_info(:export_timer, state) do
    new_state = do_export(state)
    schedule_export(state.scheduled_delay_ms)
    {:noreply, new_state}
  end

  @spec do_export(state :: map()) :: map()
  defp do_export(%{queue: [], queue_size: 0} = state), do: state

  defp do_export(%{exporter: nil} = state) do
    %{state | queue: [], queue_size: 0}
  end

  defp do_export(state) do
    {batch, remaining} = Enum.split(state.queue, state.max_export_batch_size)
    {exporter_module, exporter_state} = state.exporter
    exporter_module.export(Enum.reverse(batch), exporter_state)
    new_state = %{state | queue: remaining, queue_size: length(remaining)}
    do_export(new_state)
  end

  @spec schedule_export(delay_ms :: non_neg_integer()) :: reference()
  defp schedule_export(delay_ms) do
    Process.send_after(self(), :export_timer, delay_ms)
  end
end
