defmodule Otel.SDK.Logs.LogRecordProcessor.Batch do
  @moduledoc """
  Batching `LogRecordProcessor`
  (`logs/sdk.md` §Batching processor L528-L548).

  Spec L530-L532 — *"creates batches of `LogRecord`s and passes
  the export-friendly `ReadableLogRecord` representations to the
  configured `LogRecordExporter`."* Exports are triggered by:

  - **Queue size threshold** (`max_export_batch_size`) — emit
    pushes the queue past the threshold, immediate export.
  - **Scheduled timer** (`scheduled_delay_ms`) — periodic
    export regardless of queue size.
  - **`force_flush/1`** — explicit caller request.
  - **`shutdown/1`** — drains the queue before shutting down
    the exporter (spec §LogRecordProcessor L469).

  Spec L534-L535 — *"The processor MUST synchronize calls to
  `LogRecordExporter`'s `Export` to make sure that they are
  not invoked concurrently."* — implemented by routing every
  export through the GenServer's `handle_*` callbacks, which
  are inherently serial per-process.

  ## Public API

  | Function | Role |
  |---|---|
  | `on_emit/3`, `enabled?/3`, `shutdown/1`, `force_flush/1` | **SDK** (Batch implementation) |
  | `start_link/1` | **SDK** (lifecycle) |

  ## References

  - OTel Logs SDK Batching processor: `opentelemetry-specification/specification/logs/sdk.md` §Batching processor
  - Parent behaviour: `Otel.SDK.Logs.LogRecordProcessor`
  """

  use GenServer

  @behaviour Otel.SDK.Logs.LogRecordProcessor

  # Spec §Batching processor L540-L541: `maxQueueSize` default 2048.
  @default_max_queue_size 2048

  # Spec L542-L543: `scheduledDelayMillis` default 1000.
  @default_scheduled_delay_ms 1000

  # Spec L544-L545: `exportTimeoutMillis` default 30000.
  @default_export_timeout_ms 30_000

  # Spec L546-L547: `maxExportBatchSize` default 512.
  # MUST be ≤ `maxQueueSize`.
  @default_max_export_batch_size 512

  # --- LogRecordProcessor callbacks ---

  @doc """
  **SDK** (Batch implementation) — Enqueue the record via
  `GenServer.cast/2` (non-blocking, per spec §LogRecordProcessor
  L397 *"OnEmit ... SHOULD NOT block"*). Triggers an immediate
  export when the queue reaches `max_export_batch_size`.
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec on_emit(
          log_record :: Otel.SDK.Logs.LogRecord.t(),
          ctx :: Otel.API.Ctx.t(),
          config :: Otel.SDK.Logs.LogRecordProcessor.config()
        ) :: :ok
  def on_emit(log_record, _ctx, %{reg_name: reg_name}) do
    GenServer.cast(reg_name, {:add_record, log_record})
    :ok
  end

  @doc """
  **SDK** (Batch implementation) — Always returns `true`; the
  Batch processor has no filtering policy of its own
  (`logs/sdk.md` §LogRecordProcessor L420 *"MAY"*).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec enabled?(
          opts :: Otel.API.Logs.Logger.enabled_opts(),
          scope :: Otel.API.InstrumentationScope.t(),
          config :: Otel.SDK.Logs.LogRecordProcessor.config()
        ) :: boolean()
  def enabled?(_opts, _scope, _config), do: true

  @doc """
  **SDK** (Batch implementation) — Drain the queue via
  `do_export/1` then cascade to the exporter's `shutdown/1`.
  Returns `{:error, :already_shut_down}` on a second call so
  callers can distinguish idempotency from real failure
  (`logs/sdk.md` §LogRecordProcessor L457-L474). Spec L469 —
  *"Shutdown MUST include the effects of ForceFlush"* — the
  drain satisfies this for the processor's queue; cascading
  the exporter's `force_flush/1` would also be required (see
  the cross-cutting fix landed for Simple in PR #288 — Batch
  follow-up pending).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec shutdown(config :: Otel.SDK.Logs.LogRecordProcessor.config()) :: :ok | {:error, term()}
  def shutdown(%{reg_name: reg_name}) do
    GenServer.call(reg_name, :shutdown)
  end

  @doc """
  **SDK** (Batch implementation) — Drain the queue immediately
  (`logs/sdk.md` §LogRecordProcessor L476-L503). Spec L484-L486
  also requires invoking the exporter's `force_flush/1`
  afterward (same cross-cutting follow-up as the shutdown path).
  """
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

    scheduled_delay = Map.get(config, :scheduled_delay_ms, @default_scheduled_delay_ms)

    {:ok, exporter_state} = exporter_module.init(exporter_opts)
    exporter = {exporter_module, exporter_state}

    state = %{
      exporter: exporter,
      queue: [],
      queue_size: 0,
      max_queue_size: Map.get(config, :max_queue_size, @default_max_queue_size),
      scheduled_delay_ms: scheduled_delay,
      export_timeout_ms: Map.get(config, :export_timeout_ms, @default_export_timeout_ms),
      max_export_batch_size:
        Map.get(config, :max_export_batch_size, @default_max_export_batch_size),
      shut_down: false
    }

    schedule_export(scheduled_delay)
    {:ok, state}
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
