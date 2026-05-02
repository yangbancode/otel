defmodule Otel.SDK.Logs.LogRecordProcessor do
  @moduledoc """
  Hardcoded batching `LogRecordProcessor` — the only
  LogRecordProcessor this SDK ships.

  Implements the spec's batching processor
  (`logs/sdk.md` §Batching processor L528-L548). The
  behaviour abstraction (and a separate `Batch` impl module)
  was collapsed because the SDK ships only this processor
  and users cannot substitute their own (per minikube-style
  scope). The spec also defines a `Simple` processor
  (`logs/sdk.md` §Built-in processors), intentionally
  omitted — Simple has no overload protection (every emit
  is a synchronous export call), making it dangerous on
  BEAM under slow exporters.

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
  runner process. The `force_flush` / `shutdown` paths drain
  the queue from inside the gen_statem after the runner has
  cleared, so no two `export/2` calls overlap.

  ## State model

  Two `:gen_statem` states with `:state_enter` callbacks:

  - `:idle` — accepts cast `{:add_record, _}`, periodic
    `:export_timer`, and synchronous `{:force_flush, deadline}`
    / `{:shutdown, deadline}` calls. Transitions to
    `:exporting` when the queue threshold is met or the
    periodic timer fires with a non-empty queue.
  - `:exporting` — the `:enter` callback spawns a runner
    process (`spawn_monitor`) that calls the exporter's
    `export/2`. A `:state_timeout` of `export_timeout_ms`
    bounds the export — on expiry, the runner is killed
    (spec L544-L545 *"how long the export can run before
    it is cancelled"*). Cast `{:add_record, _}` continues
    to enqueue during export (no postpone — back-pressure
    stays at `max_queue_size`); the first
    `{:force_flush, deadline}` / `{:shutdown, deadline}` is
    saved as `pending_call` and a `:pending_deadline` generic
    timeout is armed. When the runner finishes (or that
    timeout fires) we either run the drain inside the caller's
    remaining budget or abort and reply `{:error, :timeout}` —
    spec §LogRecordProcessor L487-L491 *"MUST prioritize
    honoring the timeout over finishing all calls. It MAY
    skip or abort some or all Export or ForceFlush calls"*.
    Subsequent `force_flush` / `shutdown` calls postpone, are
    replayed in `:idle`, and each carries its own absolute
    deadline.

  No `child_spec/1` is exposed — the LoggerProvider is the
  only supervisor for this processor and it calls
  `start_link/1` directly. Users who want to put the processor
  under their own Supervisor can write a one-line spec inline.

  ## Drop reporting

  When the queue is full at emit time the new record is
  dropped (spec L540-L541 *"After the size is reached logs
  are dropped"*). Drops are silently allowed by spec, but to
  give operators visibility into sustained back-pressure we
  count them on the state and surface a throttled
  `Logger.warning` with the running total on every
  `:export_timer` tick (i.e. once per `scheduled_delay_ms`,
  default 1000ms). `terminate/3` flushes the final tally so
  no drops are lost across shutdown.

  ## Design notes

  `force_flush/2` and `shutdown/2` use `:gen_statem.call` (not
  `:cast`) to surface the result back to the caller. Spec
  §LogRecordProcessor L466-L467 / L492-L493 SHOULD provide a
  way to let the caller know whether the call succeeded,
  failed, or timed out.

  `opentelemetry-erlang` does not have a separate "batch log
  processor"; the spec gap noted above refers to erlang's
  *span* batch processor
  (`apps/opentelemetry/src/otel_batch_processor.erl`), which
  uses `gen_statem:cast` for force_flush and silently drops
  the result. That's a span-side observation, not a logs
  reference. Our logs implementation follows the Logs SDK
  spec MUST/SHOULDs directly.

  ## Public API

  | Function | Role |
  |---|---|
  | `on_emit/3`, `enabled?/3`, `shutdown/2`, `force_flush/2` | **SDK** (Batch implementation) |
  | `start_link/1` | **SDK** (lifecycle) |

  ## References

  - OTel Logs SDK §LogRecordProcessor: `opentelemetry-specification/specification/logs/sdk.md` L350-L503
  - OTel Logs SDK Batching processor: `opentelemetry-specification/specification/logs/sdk.md` §Batching processor
  """

  require Logger

  @behaviour :gen_statem

  @type config :: term()

  @typedoc """
  Subset of `Otel.API.Logs.Logger.enabled_opts/0` excluding
  `:ctx`. Spec §LogRecordProcessor L423-L426 lists the four
  `Enabled` parameters (Context, Instrumentation Scope, Severity
  Number, Event Name) as separate inputs, so this layer surfaces
  Context as the first argument of `enabled?/4` and keeps the
  remaining caller-supplied keys here.

  The SDK Logger pops `:ctx` out of the API-level
  `enabled_opts/0` before invoking `enabled?/4`, so callers
  only ever pass this subset.
  """
  @type enabled_opts :: [
          {:severity_number, Otel.API.Logs.severity_number()}
          | {:event_name, String.t()}
        ]

  defmodule State do
    @moduledoc false

    @typedoc false
    @type pending_call ::
            {:force_flush | :shutdown, :gen_statem.from(), integer() | :infinity}

    @typedoc false
    @type t :: %__MODULE__{
            exporter: {module(), Otel.SDK.Logs.LogRecordExporter.state()},
            queue: [Otel.SDK.Logs.LogRecord.t()],
            queue_size: non_neg_integer(),
            runner: {pid(), reference()} | nil,
            pending_call: pending_call() | nil,
            dropped_since_last_report: non_neg_integer()
          }
    defstruct [
      :exporter,
      queue: [],
      queue_size: 0,
      runner: nil,
      pending_call: nil,
      dropped_since_last_report: 0
    ]
  end

  @typedoc """
  `start_link/1` configuration map. Only `:exporter` is honoured —
  the four batch knobs (`max_queue_size`, `scheduled_delay_ms`,
  `export_timeout_ms`, `max_export_batch_size`) are hardcoded
  module attributes per minikube-style scope, see attributes
  defined just below.
  """
  @type start_link_config :: %{
          required(:exporter) => {module(), term()}
        }

  # Hardcoded batch knobs — the SDK ships only these values and
  # users cannot override them (per minikube-style scope). Numbers
  # follow the spec defaults at `logs/sdk.md` §Batching processor
  # L540-L547.
  @max_queue_size 2048
  @scheduled_delay_ms 1000
  @export_timeout_ms 30_000
  @max_export_batch_size 512

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
  @spec enabled?(
          ctx :: Otel.API.Ctx.t(),
          scope :: Otel.API.InstrumentationScope.t(),
          opts :: Otel.SDK.Logs.LogRecordProcessor.enabled_opts(),
          config :: Otel.SDK.Logs.LogRecordProcessor.config()
        ) :: boolean()
  def enabled?(_ctx, _scope, _opts, _config), do: true

  @doc """
  **SDK** (Batch implementation) — Drain the queue, invoke the
  exporter's `force_flush/1` then `shutdown/1`, and exit the
  gen_statem.

  `timeout` (default 30_000ms, matching spec
  `OTEL_BLRP_EXPORT_TIMEOUT`) is converted to an absolute
  deadline and forwarded to the gen_statem. Per spec
  §LogRecordProcessor L487-L491 the processor MUST honor that
  deadline over finishing all calls — drain, exporter
  `force_flush/1`, and exporter `shutdown/1` are each gated on
  the deadline; if any step would exceed it, the rest are
  skipped and `{:error, :timeout}` is returned (per L466-L467).
  Returns `{:error, :already_shutdown}` when the gen_statem has
  already terminated — spec L466-L467 classifies this as failed
  rather than silently succeeded.
  """
  @spec shutdown(
          config :: Otel.SDK.Logs.LogRecordProcessor.config(),
          timeout :: timeout()
        ) :: :ok | {:error, term()}
  def shutdown(%{pid: pid}, timeout \\ @default_shutdown_timeout_ms) do
    deadline = compute_deadline(timeout)
    :gen_statem.call(pid, {:shutdown, deadline}, timeout)
  catch
    :exit, {:noproc, _} -> {:error, :already_shutdown}
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  @doc """
  **SDK** (Batch implementation) — Drain the queue and invoke
  the exporter's `force_flush/1` (spec §LogRecordProcessor
  L484-L486 MUST). When the gen_statem is currently in
  `:exporting`, the call waits for the runner to clear; if the
  caller's deadline elapses first the runner is aborted (spec
  L487-L491 MAY).

  `timeout` (default 30_000ms) is converted to an absolute
  deadline. Drain and exporter `force_flush/1` are gated on it
  per spec L487-L491; on expiry, returns `{:error, :timeout}`
  per L492-L493. Returns `{:error, :already_shutdown}` when
  the gen_statem has already terminated — spec L492-L493
  classifies this as failed.
  """
  @spec force_flush(
          config :: Otel.SDK.Logs.LogRecordProcessor.config(),
          timeout :: timeout()
        ) :: :ok | {:error, term()}
  def force_flush(%{pid: pid}, timeout \\ @default_force_flush_timeout_ms) do
    deadline = compute_deadline(timeout)
    :gen_statem.call(pid, {:force_flush, deadline}, timeout)
  catch
    :exit, {:noproc, _} -> {:error, :already_shutdown}
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  # --- gen_statem lifecycle ---

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
    state = %State{
      exporter: Otel.SDK.Exporter.Init.call(Map.fetch!(config, :exporter))
    }

    schedule_periodic_export()
    {:ok, :idle, state}
  end

  # --- State: :idle ---

  @spec idle(
          event_type :: :gen_statem.event_type(),
          event_content ::
            :idle
            | :exporting
            | {:add_record, Otel.SDK.Logs.LogRecord.t()}
            | {:force_flush | :shutdown, integer() | :infinity}
            | :export_timer
            | :pending_deadline
            | {:export_done, pid()}
            | {:DOWN, reference(), :process, pid(), term()},
          state :: State.t()
        ) :: :gen_statem.event_handler_result(State.t())
  def idle(:enter, _old_state, _state), do: :keep_state_and_data

  def idle(:cast, {:add_record, log_record}, state) do
    state = enqueue(state, log_record)

    if state.queue_size >= @max_export_batch_size do
      {:next_state, :exporting, state}
    else
      {:keep_state, state}
    end
  end

  def idle({:call, from}, {:force_flush, deadline}, state) do
    state = drain_all_sync(state, deadline)

    result =
      if deadline_exceeded?(deadline) do
        {:error, :timeout}
      else
        {module, exporter_state} = state.exporter
        module.force_flush(exporter_state)
      end

    {:keep_state, state, [{:reply, from, result}]}
  end

  def idle({:call, from}, {:shutdown, deadline}, state) do
    state = drain_all_sync(state, deadline)
    {module, exporter_state} = state.exporter

    result =
      if deadline_exceeded?(deadline) do
        {:error, :timeout}
      else
        # Spec §LogRecordProcessor L469: "Shutdown MUST include the
        # effects of ForceFlush" — flush exporter buffers before
        # tearing it down.
        module.force_flush(exporter_state)
        module.shutdown(exporter_state)
        :ok
      end

    {:stop_and_reply, :normal, [{:reply, from, result}], state}
  end

  def idle(:info, :export_timer, state) do
    schedule_periodic_export()
    state = report_drops_if_any(state)

    if state.queue_size > 0 do
      {:next_state, :exporting, state}
    else
      {:keep_state, state}
    end
  end

  # Stale `:pending_deadline` generic-timeout from a runner that
  # finished or was killed before the deadline fired in
  # `:exporting`. Generic timeouts persist across state changes,
  # so absorb the late event here.
  def idle({:timeout, :pending_deadline}, _content, _state), do: :keep_state_and_data

  # Stray `:export_done` / `:DOWN` from a runner aborted by
  # `abort_runner/1` after we transitioned out of `:exporting`.
  def idle(:info, {:export_done, _pid}, _state), do: :keep_state_and_data
  def idle(:info, {:DOWN, _ref, :process, _pid, _reason}, _state), do: :keep_state_and_data

  # --- State: :exporting ---

  @spec exporting(
          event_type :: :gen_statem.event_type(),
          event_content ::
            :idle
            | :exporting
            | {:add_record, Otel.SDK.Logs.LogRecord.t()}
            | {:force_flush | :shutdown, integer() | :infinity}
            | :export_timer
            | :export_timeout
            | :pending_deadline
            | {:export_done, pid()}
            | {:DOWN, reference(), :process, pid(), term()},
          state :: State.t()
        ) :: :gen_statem.event_handler_result(State.t())
  def exporting(:enter, _old_state, state) do
    state = start_export(state)
    {:keep_state, state, [{:state_timeout, @export_timeout_ms, :export_timeout}]}
  end

  def exporting(:cast, {:add_record, log_record}, state) do
    {:keep_state, enqueue(state, log_record)}
  end

  # First `force_flush` / `shutdown` while exporting — save as
  # `pending_call` and arm a `:pending_deadline` generic timeout.
  # When the runner completes (or the deadline fires first), we
  # reply to the caller. Spec §LogRecordProcessor L487-L491:
  # *"MUST prioritize honoring the timeout over finishing all
  # calls. It MAY skip or abort some or all Export or ForceFlush
  # calls it has made to achieve this goal."*
  def exporting(
        {:call, from},
        {tag, deadline},
        %State{pending_call: nil} = state
      )
      when tag in [:force_flush, :shutdown] do
    case deadline_remaining(deadline) do
      :exceeded ->
        # Caller's budget already gone — abort runner immediately.
        state = abort_runner(state)
        reply_pending(tag, from, {:error, :timeout}, state)

      remaining ->
        state = %State{state | pending_call: {tag, from, deadline}}
        {:keep_state, state, [{{:timeout, :pending_deadline}, remaining, :pending_deadline}]}
    end
  end

  # Subsequent `force_flush` / `shutdown` while a `pending_call` is
  # already armed — postpone. They will be replayed in `:idle` after
  # the pending one resolves; each carries its own deadline.
  def exporting({:call, _from}, {tag, _deadline}, _state)
      when tag in [:force_flush, :shutdown] do
    {:keep_state_and_data, [:postpone]}
  end

  def exporting(:info, :export_timer, state) do
    schedule_periodic_export()
    {:keep_state, report_drops_if_any(state)}
  end

  def exporting(:info, {:export_done, pid}, %State{runner: {pid, ref}} = state) do
    Process.demonitor(ref, [:flush])
    after_runner(%State{state | runner: nil})
  end

  def exporting(:info, {:DOWN, ref, :process, pid, reason}, %State{runner: {pid, ref}} = state) do
    warn_exporter_crashed(reason)
    after_runner(%State{state | runner: nil})
  end

  def exporting(:state_timeout, :export_timeout, %State{runner: {pid, ref}} = state) do
    Process.demonitor(ref, [:flush])
    Process.exit(pid, :kill)
    warn_exporter_timeout(@export_timeout_ms)
    after_runner(%State{state | runner: nil})
  end

  # Pending caller's deadline expired before the runner finished —
  # abort runner and reply timeout to the caller.
  def exporting({:timeout, :pending_deadline}, :pending_deadline, %State{pending_call: nil}) do
    # Stale (race with `:export_done` clearing pending_call) — ignore.
    :keep_state_and_data
  end

  def exporting(
        {:timeout, :pending_deadline},
        :pending_deadline,
        %State{pending_call: {tag, from, _deadline}} = state
      ) do
    state = abort_runner(state)
    reply_pending(tag, from, {:error, :timeout}, %State{state | pending_call: nil})
  end

  # --- terminate ---

  # Final flush of the throttled drop counter so an operator never
  # loses the last batch of "queue full" drops that arrived between
  # the last `:export_timer` tick and shutdown.
  @impl :gen_statem
  @spec terminate(reason :: term(), state_name :: atom(), state :: State.t()) :: :ok
  def terminate(_reason, _state_name, state) do
    _ = report_drops_if_any(state)
    :ok
  end

  # --- Private helpers ---

  @spec enqueue(state :: State.t(), log_record :: Otel.SDK.Logs.LogRecord.t()) :: State.t()
  defp enqueue(state, _log_record) when state.queue_size >= @max_queue_size do
    # Queue full — drop record (spec L540-L541). Count it; the next
    # `:export_timer` cycle will surface the throttled total via
    # `report_drops_if_any/1` so operators can observe sustained
    # back-pressure without being spammed once per dropped record.
    %State{state | dropped_since_last_report: state.dropped_since_last_report + 1}
  end

  defp enqueue(state, log_record) do
    %State{state | queue: [log_record | state.queue], queue_size: state.queue_size + 1}
  end

  @spec report_drops_if_any(state :: State.t()) :: State.t()
  defp report_drops_if_any(%State{dropped_since_last_report: 0} = state), do: state

  defp report_drops_if_any(%State{dropped_since_last_report: count} = state) do
    warn_queue_full_drops(count)
    %State{state | dropped_since_last_report: 0}
  end

  # Spec `logs/sdk.md` L540-L541 — when the queue is at
  # `max_queue_size`, additional log records MUST be dropped.
  # We warn once per `:export_timer` cycle with the running
  # total so operators see sustained back-pressure without
  # being spammed once-per-record.
  @spec warn_queue_full_drops(count :: pos_integer()) :: :ok
  defp warn_queue_full_drops(count) do
    Logger.warning(
      "Otel.SDK.Logs.LogRecordProcessor: queue full — dropped #{count} " <>
        "log record#{if count == 1, do: "", else: "s"} since last report"
    )

    :ok
  end

  # Emitted from `:DOWN` runner-crash handler. Not in spec —
  # operational signal so users can correlate dropped batches
  # with a crash report.
  @spec warn_exporter_crashed(reason :: term()) :: :ok
  defp warn_exporter_crashed(reason) do
    Logger.warning(
      "Otel.SDK.Logs.LogRecordProcessor: exporter crashed with " <>
        "#{inspect(reason)} — batch dropped, processor remains active"
    )

    :ok
  end

  # Emitted when the runner exceeds `export_timeout_ms`. We
  # kill the runner first; this warning surfaces the choice
  # to the operator.
  @spec warn_exporter_timeout(timeout_ms :: pos_integer()) :: :ok
  defp warn_exporter_timeout(timeout_ms) do
    Logger.warning(
      "Otel.SDK.Logs.LogRecordProcessor: exporter timed out after " <>
        "#{timeout_ms}ms — runner killed, batch dropped"
    )

    :ok
  end

  @spec start_export(state :: State.t()) :: State.t()
  defp start_export(state) do
    {batch_reversed, remaining} = Enum.split(state.queue, @max_export_batch_size)
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

  # Called after the runner finishes (naturally, by crash, or by
  # export-timeout kill). Hands off to the pending caller if one
  # is waiting, otherwise resumes the periodic batching cycle.
  @spec after_runner(state :: State.t()) :: :gen_statem.event_handler_result(State.t())
  defp after_runner(%State{pending_call: nil} = state), do: next_after_export(state)

  defp after_runner(%State{pending_call: pending} = state),
    do: handle_pending_call(pending, state)

  @spec next_after_export(state :: State.t()) :: :gen_statem.event_handler_result(State.t())
  defp next_after_export(%State{queue_size: 0} = state) do
    {:next_state, :idle, state}
  end

  defp next_after_export(state) do
    state = start_export(state)
    {:keep_state, state, [{:state_timeout, @export_timeout_ms, :export_timeout}]}
  end

  # Drain whatever fits in the deadline, then run the exporter's
  # `force_flush/1` / `shutdown/1` (also deadline-bounded), and
  # reply to the pending caller. Reached only after a runner has
  # cleared, so we always start in a runner-less state.
  @spec handle_pending_call(pending :: State.pending_call(), state :: State.t()) ::
          :gen_statem.event_handler_result(State.t())
  defp handle_pending_call({:force_flush, from, deadline}, state) do
    state = drain_all_sync(state, deadline)

    result =
      if deadline_exceeded?(deadline) do
        {:error, :timeout}
      else
        {module, exporter_state} = state.exporter
        module.force_flush(exporter_state)
      end

    state = %State{state | pending_call: nil}
    {:next_state, :idle, state, [{:reply, from, result}]}
  end

  defp handle_pending_call({:shutdown, from, deadline}, state) do
    state = drain_all_sync(state, deadline)
    {module, exporter_state} = state.exporter

    result =
      if deadline_exceeded?(deadline) do
        {:error, :timeout}
      else
        # Spec L469: "Shutdown MUST include the effects of ForceFlush".
        module.force_flush(exporter_state)
        module.shutdown(exporter_state)
        :ok
      end

    {:stop_and_reply, :normal, [{:reply, from, result}], state}
  end

  # Reply to a `pending_call` while still in `:exporting` (called by
  # the immediate-deadline and pending-timeout paths). Mirrors
  # `handle_pending_call/2` but skips the drain — the caller is
  # already past their deadline so we just signal and transition.
  @spec reply_pending(
          tag :: :force_flush | :shutdown,
          from :: :gen_statem.from(),
          reply :: term(),
          state :: State.t()
        ) :: :gen_statem.event_handler_result(State.t())
  defp reply_pending(:force_flush, from, reply, state) do
    {:next_state, :idle, state, [{:reply, from, reply}]}
  end

  defp reply_pending(:shutdown, from, reply, state) do
    {:stop_and_reply, :normal, [{:reply, from, reply}], state}
  end

  # Force-kill the in-flight runner so we can either honor a tighter
  # caller deadline or transition to `:idle` immediately. Spec
  # §LogRecordProcessor L487-L491 explicitly allows aborting in-
  # progress export calls in service of the timeout.
  @spec abort_runner(state :: State.t()) :: State.t()
  defp abort_runner(%State{runner: nil} = state), do: state

  defp abort_runner(%State{runner: {pid, ref}} = state) do
    Process.demonitor(ref, [:flush])
    Process.exit(pid, :kill)
    %State{state | runner: nil}
  end

  @spec compute_deadline(timeout :: timeout()) :: integer() | :infinity
  defp compute_deadline(:infinity), do: :infinity

  defp compute_deadline(timeout) when is_integer(timeout) and timeout >= 0 do
    System.monotonic_time(:millisecond) + timeout
  end

  @spec deadline_exceeded?(deadline :: integer() | :infinity) :: boolean()
  defp deadline_exceeded?(:infinity), do: false
  defp deadline_exceeded?(deadline), do: System.monotonic_time(:millisecond) >= deadline

  @spec deadline_remaining(deadline :: integer() | :infinity) ::
          non_neg_integer() | :infinity | :exceeded
  defp deadline_remaining(:infinity), do: :infinity

  defp deadline_remaining(deadline) do
    case deadline - System.monotonic_time(:millisecond) do
      remaining when remaining > 0 -> remaining
      _ -> :exceeded
    end
  end

  @spec drain_all_sync(state :: State.t(), deadline :: integer() | :infinity) :: State.t()
  defp drain_all_sync(%State{queue_size: 0} = state, _deadline), do: state

  defp drain_all_sync(state, deadline) do
    if deadline_exceeded?(deadline) do
      state
    else
      {batch_reversed, remaining} = Enum.split(state.queue, @max_export_batch_size)
      batch = Enum.reverse(batch_reversed)
      {module, exporter_state} = state.exporter
      module.export(batch, exporter_state)

      drain_all_sync(
        %State{state | queue: remaining, queue_size: state.queue_size - length(batch_reversed)},
        deadline
      )
    end
  end

  @spec schedule_periodic_export() :: reference()
  defp schedule_periodic_export do
    Process.send_after(self(), :export_timer, @scheduled_delay_ms)
  end
end
