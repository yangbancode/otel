defmodule Otel.SDK.Logs.LogRecordProcessor.Batch do
  @moduledoc """
  Batching `LogRecordProcessor`
  (`logs/sdk.md` §Batching processor L528-L548).

  Spec L530-L532 — *"creates batches of `LogRecord`s and passes
  the export-friendly `ReadableLogRecord` representations to the
  configured `LogRecordExporter`."* Exports are triggered by:

  - **Queue size threshold** (`max_export_batch_size`) — a
    cast that pushes the queue past the threshold transitions
    immediately to `:exporting`.
  - **Scheduled timer** (`scheduled_delay_ms`) — periodic
    `:export_timer` info while in `:idle` triggers an export
    if the queue is non-empty.
  - **`force_flush/2`** — synchronous drain of the entire
    queue followed by the exporter's `force_flush/1`
    (spec §LogRecordProcessor L484-L486 MUST).
  - **`shutdown/2`** — synchronous drain plus exporter's
    `force_flush/1` then `shutdown/1` (spec L469 MUST that
    *"Shutdown MUST include the effects of ForceFlush"*).
    The gen_statem then exits via `{:stop_and_reply, :normal,
    ...}`, mirroring the Simple processor pattern (PR #292).

  Spec L534-L535 — *"The processor MUST synchronize calls to
  `LogRecordExporter`'s `Export` to make sure that they are
  not invoked concurrently."* — the gen_statem's mailbox
  serialises events, and only the `:exporting` state owns a
  runner process. Postpone of `:force_flush` / `:shutdown`
  during `:exporting` ensures their drains happen *after*
  the in-progress runner completes.

  ## State model

  Two `:gen_statem` states with `:state_enter` callbacks:

  - `:idle` — accepts cast `{:add_record, _}`, periodic
    `:export_timer`, and synchronous `:force_flush` /
    `:shutdown` calls. Transitions to `:exporting` when
    the queue threshold is met or the periodic timer fires
    with a non-empty queue.
  - `:exporting` — the `:enter` callback spawns a runner
    process (`spawn_monitor`) that calls the exporter's
    `export/2`. A `:state_timeout` of `export_timeout_ms`
    bounds the export — on expiry, the runner is killed
    (spec L544-L545 *"how long the export can run before
    it is cancelled"*). Cast `{:add_record, _}` continues
    to enqueue during export (no postpone — back-pressure
    stays at `max_queue_size`); `:force_flush` and
    `:shutdown` calls are postponed until the runner
    completes.

  Supervisor `restart: :transient` means a `:normal` exit
  from a successful `shutdown/2` does not auto-restart,
  while crashes still do.

  ## Design notes

  `force_flush/2` and `shutdown/2` use `:gen_statem.call` (not
  `:cast`) to surface the result back to the caller. Spec
  §LogRecordProcessor L466-L467 / L492-L493 SHOULD provide a
  way to let the caller know whether the call succeeded,
  failed, or timed out. The erlang reference uses
  `gen_statem:cast` for `force_flush` (`otel_batch_processor.erl`),
  which silently drops the result and violates the SHOULD —
  we follow spec.

  ## Public API

  | Function | Role |
  |---|---|
  | `on_emit/3`, `enabled?/3`, `shutdown/2`, `force_flush/2` | **SDK** (Batch implementation) |
  | `start_link/1` | **SDK** (lifecycle) |

  ## References

  - OTel Logs SDK Batching processor: `opentelemetry-specification/specification/logs/sdk.md` §Batching processor
  - Erlang reference: `opentelemetry-erlang/apps/opentelemetry/src/otel_batch_processor.erl`
  - Parent behaviour: `Otel.SDK.Logs.LogRecordProcessor`
  """

  require Logger

  @behaviour :gen_statem
  @behaviour Otel.SDK.Logs.LogRecordProcessor

  defmodule State do
    @moduledoc false

    @typedoc false
    @type t :: %__MODULE__{
            exporter: {module(), Otel.SDK.Logs.LogRecordExporter.state()},
            queue: [Otel.SDK.Logs.LogRecord.t()],
            queue_size: non_neg_integer(),
            max_queue_size: pos_integer(),
            scheduled_delay_ms: non_neg_integer(),
            export_timeout_ms: non_neg_integer(),
            max_export_batch_size: pos_integer(),
            runner: {pid(), reference()} | nil
          }
    defstruct [
      :exporter,
      :max_queue_size,
      :scheduled_delay_ms,
      :export_timeout_ms,
      :max_export_batch_size,
      queue: [],
      queue_size: 0,
      runner: nil
    ]
  end

  @typedoc """
  `start_link/1` configuration map. All keys except `:exporter`
  default to the spec-defined values from §Batching processor
  L540-L547.

  - `:exporter` (**required**) — `{module, opts}`; `opts` is
    passed to `module.init/1` once at startup.
  - `:max_queue_size` (optional) — spec L540-L541, default 2048.
  - `:scheduled_delay_ms` (optional) — spec L542-L543, default 1000.
  - `:export_timeout_ms` (optional) — spec L544-L545, default 30000.
  - `:max_export_batch_size` (optional) — spec L546-L547, default 512.
    MUST be ≤ `max_queue_size`.
  """
  @type start_link_config :: %{
          required(:exporter) => {module(), term()},
          optional(:max_queue_size) => pos_integer(),
          optional(:scheduled_delay_ms) => non_neg_integer(),
          optional(:export_timeout_ms) => non_neg_integer(),
          optional(:max_export_batch_size) => pos_integer()
        }

  # Spec §Batching processor L540-L541: `maxQueueSize` default 2048.
  @default_max_queue_size 2048

  # Spec L542-L543: `scheduledDelayMillis` default 1000.
  @default_scheduled_delay_ms 1000

  # Spec L544-L545: `exportTimeoutMillis` default 30000.
  @default_export_timeout_ms 30_000

  # Spec L546-L547: `maxExportBatchSize` default 512.
  # MUST be ≤ `maxQueueSize`.
  @default_max_export_batch_size 512

  # Default timeout for `force_flush/2` and `shutdown/2`. Matches
  # spec `OTEL_BLRP_EXPORT_TIMEOUT` default (30000ms) — the same
  # per-export budget the runner enforces via `state_timeout`.
  @default_force_flush_timeout_ms 30_000
  @default_shutdown_timeout_ms 30_000

  # --- LogRecordProcessor callbacks ---

  @doc """
  **SDK** (Batch implementation) — Enqueue the record via
  `:gen_statem.cast/2` (non-blocking, per spec
  §LogRecordProcessor L394-L396 *"called synchronously on the
  thread that emitted the LogRecord, therefore it SHOULD NOT
  block or throw exceptions"*). Triggers an immediate
  transition to `:exporting` when the queue reaches
  `max_export_batch_size`.
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec on_emit(
          log_record :: Otel.SDK.Logs.LogRecord.t(),
          ctx :: Otel.API.Ctx.t(),
          config :: Otel.SDK.Logs.LogRecordProcessor.config()
        ) :: :ok
  def on_emit(log_record, _ctx, %{pid: pid}) do
    :gen_statem.cast(pid, {:add_record, log_record})
    :ok
  end

  @doc """
  **SDK** (Batch implementation) — Always returns `true`; the
  Batch processor has no filtering policy of its own
  (`logs/sdk.md` §LogRecordProcessor L420 *"MAY implement"*).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec enabled?(
          opts :: Otel.API.Logs.Logger.enabled_opts(),
          scope :: Otel.API.InstrumentationScope.t(),
          config :: Otel.SDK.Logs.LogRecordProcessor.config()
        ) :: boolean()
  def enabled?(_opts, _scope, _config), do: true

  @doc """
  **SDK** (Batch implementation) — Drain the queue, invoke the
  exporter's `force_flush/1` then `shutdown/1`, and exit the
  gen_statem.

  `timeout` (default 30_000ms, matching spec
  `OTEL_BLRP_EXPORT_TIMEOUT`) bounds the call. Returns
  `{:error, :timeout}` if exceeded, per spec L466-L467 /
  L487-L491. Returns `:ok` silently when the gen_statem has
  already terminated, per spec §LogRecordProcessor L462-L464
  *"SDKs SHOULD ignore these calls gracefully"* (covers
  idempotent re-entry from a duplicate `shutdown/2`).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec shutdown(
          config :: Otel.SDK.Logs.LogRecordProcessor.config(),
          timeout :: timeout()
        ) :: :ok | {:error, term()}
  def shutdown(%{pid: pid}, timeout \\ @default_shutdown_timeout_ms) do
    :gen_statem.call(pid, :shutdown, timeout)
  catch
    :exit, {:noproc, _} -> :ok
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  @doc """
  **SDK** (Batch implementation) — Drain the queue and invoke
  the exporter's `force_flush/1` (spec §LogRecordProcessor
  L484-L486 MUST). When the gen_statem is currently in
  `:exporting`, the call is postponed until the in-progress
  runner completes.

  `timeout` (default 30_000ms) bounds the call. Returns
  `{:error, :timeout}` if exceeded, per spec L492-L493 /
  L487-L491. Returns `:ok` silently when the gen_statem has
  already terminated, per spec L462-L464.
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec force_flush(
          config :: Otel.SDK.Logs.LogRecordProcessor.config(),
          timeout :: timeout()
        ) :: :ok | {:error, term()}
  def force_flush(%{pid: pid}, timeout \\ @default_force_flush_timeout_ms) do
    :gen_statem.call(pid, :force_flush, timeout)
  catch
    :exit, {:noproc, _} -> :ok
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  # --- gen_statem lifecycle ---

  @spec child_spec(arg :: term()) :: Supervisor.child_spec()
  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]},
      type: :worker,
      restart: :transient
    }
  end

  @spec start_link(config :: start_link_config()) :: :gen_statem.start_ret()
  def start_link(config) do
    :gen_statem.start_link(__MODULE__, config, [])
  end

  @impl :gen_statem
  @spec callback_mode() :: [:state_functions | :state_enter, ...]
  def callback_mode, do: [:state_functions, :state_enter]

  @impl :gen_statem
  @spec init(config :: start_link_config()) :: {:ok, :idle, State.t()}
  def init(config) do
    {exporter_module, exporter_opts} = Map.fetch!(config, :exporter)
    {:ok, exporter_state} = exporter_module.init(exporter_opts)

    state = %State{
      exporter: {exporter_module, exporter_state},
      max_queue_size: Map.get(config, :max_queue_size, @default_max_queue_size),
      scheduled_delay_ms: Map.get(config, :scheduled_delay_ms, @default_scheduled_delay_ms),
      export_timeout_ms: Map.get(config, :export_timeout_ms, @default_export_timeout_ms),
      max_export_batch_size:
        Map.get(config, :max_export_batch_size, @default_max_export_batch_size)
    }

    schedule_periodic_export(state.scheduled_delay_ms)
    {:ok, :idle, state}
  end

  # --- State: :idle ---

  @spec idle(
          event_type :: :gen_statem.event_type(),
          event_content :: term(),
          state :: State.t()
        ) :: :gen_statem.event_handler_result(State.t())
  def idle(:enter, _old_state, _state), do: :keep_state_and_data

  def idle(:cast, {:add_record, log_record}, state) do
    state = enqueue(state, log_record)

    if state.queue_size >= state.max_export_batch_size do
      {:next_state, :exporting, state}
    else
      {:keep_state, state}
    end
  end

  def idle({:call, from}, :force_flush, state) do
    state = drain_all_sync(state)
    {module, exporter_state} = state.exporter
    result = module.force_flush(exporter_state)
    {:keep_state, state, [{:reply, from, result}]}
  end

  def idle({:call, from}, :shutdown, state) do
    state = drain_all_sync(state)
    {module, exporter_state} = state.exporter
    # Spec §LogRecordProcessor L469: "Shutdown MUST include the
    # effects of ForceFlush" — flush exporter buffers before
    # tearing it down.
    module.force_flush(exporter_state)
    module.shutdown(exporter_state)
    {:stop_and_reply, :normal, [{:reply, from, :ok}], state}
  end

  def idle(:info, :export_timer, state) do
    schedule_periodic_export(state.scheduled_delay_ms)

    if state.queue_size > 0 do
      {:next_state, :exporting, state}
    else
      {:keep_state, state}
    end
  end

  # --- State: :exporting ---

  @spec exporting(
          event_type :: :gen_statem.event_type(),
          event_content :: term(),
          state :: State.t()
        ) :: :gen_statem.event_handler_result(State.t())
  def exporting(:enter, _old_state, state) do
    state = start_export(state)
    {:keep_state, state, [{:state_timeout, state.export_timeout_ms, :export_timeout}]}
  end

  def exporting(:cast, {:add_record, log_record}, state) do
    {:keep_state, enqueue(state, log_record)}
  end

  def exporting({:call, _from}, :force_flush, _state) do
    {:keep_state_and_data, [:postpone]}
  end

  def exporting({:call, _from}, :shutdown, _state) do
    {:keep_state_and_data, [:postpone]}
  end

  def exporting(:info, :export_timer, state) do
    schedule_periodic_export(state.scheduled_delay_ms)
    :keep_state_and_data
  end

  def exporting(:info, {:export_done, pid}, %State{runner: {pid, ref}} = state) do
    Process.demonitor(ref, [:flush])
    next_after_export(%State{state | runner: nil})
  end

  def exporting(:info, {:DOWN, ref, :process, pid, reason}, %State{runner: {pid, ref}} = state) do
    Logger.warning("Otel.SDK.Logs.LogRecordProcessor.Batch: exporter crashed: #{inspect(reason)}")

    next_after_export(%State{state | runner: nil})
  end

  def exporting(:state_timeout, :export_timeout, %State{runner: {pid, ref}} = state) do
    Process.demonitor(ref, [:flush])
    Process.exit(pid, :kill)

    Logger.warning(
      "Otel.SDK.Logs.LogRecordProcessor.Batch: exporter timed out after #{state.export_timeout_ms}ms"
    )

    next_after_export(%State{state | runner: nil})
  end

  # --- Private helpers ---

  @spec enqueue(state :: State.t(), log_record :: Otel.SDK.Logs.LogRecord.t()) :: State.t()
  defp enqueue(state, _log_record) when state.queue_size >= state.max_queue_size do
    # Queue full — drop record (spec L540-L541).
    state
  end

  defp enqueue(state, log_record) do
    %State{state | queue: [log_record | state.queue], queue_size: state.queue_size + 1}
  end

  @spec start_export(state :: State.t()) :: State.t()
  defp start_export(state) do
    {batch_reversed, remaining} = Enum.split(state.queue, state.max_export_batch_size)
    batch = Enum.reverse(batch_reversed)
    {pid, ref} = spawn_runner(self(), state.exporter, batch)

    %State{
      state
      | runner: {pid, ref},
        queue: remaining,
        queue_size: state.queue_size - length(batch_reversed)
    }
  end

  @spec spawn_runner(
          parent :: pid(),
          exporter :: {module(), Otel.SDK.Logs.LogRecordExporter.state()},
          batch :: [Otel.SDK.Logs.LogRecord.t()]
        ) :: {pid(), reference()}
  defp spawn_runner(parent, {module, exporter_state}, batch) do
    spawn_monitor(fn ->
      module.export(batch, exporter_state)
      send(parent, {:export_done, self()})
    end)
  end

  @spec next_after_export(state :: State.t()) :: :gen_statem.event_handler_result(State.t())
  defp next_after_export(%State{queue_size: 0} = state) do
    {:next_state, :idle, state}
  end

  defp next_after_export(state) do
    state = start_export(state)
    {:keep_state, state, [{:state_timeout, state.export_timeout_ms, :export_timeout}]}
  end

  @spec drain_all_sync(state :: State.t()) :: State.t()
  defp drain_all_sync(%State{queue_size: 0} = state), do: state

  defp drain_all_sync(state) do
    {batch_reversed, remaining} = Enum.split(state.queue, state.max_export_batch_size)
    batch = Enum.reverse(batch_reversed)
    {module, exporter_state} = state.exporter
    module.export(batch, exporter_state)

    drain_all_sync(%State{
      state
      | queue: remaining,
        queue_size: state.queue_size - length(batch_reversed)
    })
  end

  @spec schedule_periodic_export(delay_ms :: non_neg_integer()) :: reference()
  defp schedule_periodic_export(delay_ms) do
    Process.send_after(self(), :export_timer, delay_ms)
  end
end
