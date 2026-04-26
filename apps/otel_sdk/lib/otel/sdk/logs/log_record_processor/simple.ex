defmodule Otel.SDK.Logs.LogRecordProcessor.Simple do
  @moduledoc """
  Simple `LogRecordProcessor` (`logs/sdk.md` §Simple processor
  L514-L527).

  Spec L516-L519 — *"passes finished logs and passes the
  export-friendly `ReadableLogRecord` representation to the
  configured `LogRecordExporter`, as soon as they are
  finished."*

  Spec L521-L522 — *"The processor MUST synchronize calls to
  `LogRecordExporter`'s `Export` to make sure that they are
  not invoked concurrently."* — implemented by routing every
  emit through `:gen_statem.call/2`, which is inherently
  serial per-process.

  Spec L526 — the only configurable parameter is `exporter`.

  ## Lifecycle ownership

  This processor is started by `Otel.SDK.Logs.LoggerProvider`
  (typical OTel SDK pattern, matching erlang's
  `otel_tracer_server.erl:158-183`). The user supplies the
  `start_link/1` config to LoggerProvider's processors list;
  LoggerProvider then calls `start_link/1`, captures the PID,
  links to it, and passes that PID to the behaviour callbacks
  via the `%{pid: pid}` config. The gen_statem is therefore
  unregistered (no atom name) — PIDs are first-class.

  ## Non-blocking emit

  `on_emit/3` is non-blocking per spec §LogRecordProcessor
  L394-L396 — *"called synchronously on the thread that
  emitted the LogRecord, therefore it SHOULD NOT block or
  throw exceptions"*. The processor uses `:gen_statem.cast/2`
  to enqueue the record and returns immediately; the
  gen_statem then runs the exporter's `export/2` in its own
  process. This satisfies §Simple processor L515-L518 (*"as
  soon as they are finished"* — no batching) together with
  L521-L522 (*"MUST synchronize calls to LogRecordExporter's
  Export to make sure that they are not invoked concurrently"*).

  Diverges from
  `opentelemetry-erlang/apps/opentelemetry/src/otel_simple_processor.erl`,
  which uses `gen_statem:call` (blocks the emit thread, violating
  spec L394-L396). We follow spec per the project's
  spec-over-erlang rule.

  ## State model and shutdown

  One `:gen_statem` state, `:running`. The processor accepts
  `:export` and `:force_flush` requests there. Shutdown
  terminates the gen_statem rather than transitioning to a
  parked state — `shutdown/2` calls
  `:gen_statem.stop(__MODULE__, :normal, timeout)`, which
  invokes `terminate/3` (where the exporter's `force_flush/1`
  and `shutdown/1` run, satisfying spec L469
  *"Shutdown MUST include the effects of ForceFlush"*) and
  then exits the process cleanly.

  Late-arriving `on_emit/3` after termination is silently
  dropped — `:gen_statem.cast/2` to a dead pid is dead-lettered
  and returns `:ok`. Late `force_flush/2` or a second
  `shutdown/2` still go through `:gen_statem.call` /
  `:gen_statem.stop`, so they catch `:exit, {:noproc, _}` /
  `:exit, :noproc` and return `:ok`. All three satisfy spec
  §LogRecordProcessor L462-L464 *"SDKs SHOULD ignore these
  calls gracefully"*.

  When the day comes that we want hung-exporter timeout
  isolation, an additional `:exporting` state with a runner
  process would slot in here cleanly. For now, single state.

  No `child_spec/1` is exposed — the LoggerProvider is the
  only supervisor for this processor and it calls
  `start_link/1` directly. Users who want to put the processor
  under their own Supervisor can write a one-line spec inline.

  ## Public API

  | Function | Role |
  |---|---|
  | `on_emit/3`, `enabled?/3`, `shutdown/2`, `force_flush/2` | **SDK** (Simple implementation) |
  | `start_link/1` | **SDK** (lifecycle) |

  ## References

  - OTel Logs SDK Simple processor: `opentelemetry-specification/specification/logs/sdk.md` §Simple processor
  - Parent behaviour: `Otel.SDK.Logs.LogRecordProcessor`
  """

  @behaviour :gen_statem
  @behaviour Otel.SDK.Logs.LogRecordProcessor

  defmodule State do
    @moduledoc false

    @typedoc false
    @type t :: %__MODULE__{
            exporter: {module(), Otel.SDK.Logs.LogRecordExporter.state()}
          }
    defstruct [:exporter]
  end

  @typedoc """
  `start_link/1` configuration map.

  - `:exporter` (**required**) — `{module, opts}` where `module`
    implements `Otel.SDK.Logs.LogRecordExporter` and `opts` is
    passed to `module.init/1` once at startup.
  """
  @type start_link_config :: %{required(:exporter) => {module(), term()}}

  # Default timeout for `force_flush/2` and `shutdown/2` (30000ms).
  # Same value as Batch's `exportTimeoutMillis` default — a
  # reasonable upper bound for the exporter's own `force_flush/1`
  # + `shutdown/1`, the slowest path during processor cleanup.
  @default_force_flush_timeout_ms 30_000
  @default_shutdown_timeout_ms 30_000

  # --- LogRecordProcessor callbacks ---

  @doc """
  **SDK** (Simple implementation) — Cast the emitted record
  to the gen_statem for serialised export, satisfying spec
  §LogRecordProcessor L394-L396 (*"SHOULD NOT block"*) and
  §Simple processor L521-L522 (*"MUST synchronize calls to
  LogRecordExporter's Export"*). Returns `:ok` immediately;
  late casts after termination are silently dead-lettered, per
  spec L462-L464.
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec on_emit(
          log_record :: Otel.SDK.Logs.LogRecord.t(),
          ctx :: Otel.API.Ctx.t(),
          config :: Otel.SDK.Logs.LogRecordProcessor.config()
        ) :: :ok
  def on_emit(log_record, _ctx, %{pid: pid}) do
    :gen_statem.cast(pid, {:export, log_record})
  end

  @doc """
  **SDK** (Simple implementation) — Always returns `true`; the
  Simple processor has no filtering policy of its own
  (`logs/sdk.md` §LogRecordProcessor L420 *"MAY implement"*).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec enabled?(
          ctx :: Otel.API.Ctx.t(),
          scope :: Otel.API.InstrumentationScope.t(),
          opts :: Otel.SDK.Logs.LogRecordProcessor.enabled_opts(),
          config :: Otel.SDK.Logs.LogRecordProcessor.config()
        ) :: boolean()
  def enabled?(_ctx, _scope, _opts, _config), do: true

  @doc """
  **SDK** (Simple implementation) — Synchronously stop the
  gen_statem via `:gen_statem.stop/3`. The `terminate/3`
  callback runs the exporter's `force_flush/1` then
  `shutdown/1` (spec L469) before the process exits.

  `timeout` (default 30_000ms) bounds the wait for terminate
  to complete. Returns `{:error, :timeout}` if exceeded,
  per spec L466-L467 / L487-L491. Returns `:ok` silently when
  the gen_statem has already terminated, per spec L462-L464
  (covers idempotent re-entry from a duplicate `shutdown/2`).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec shutdown(
          config :: Otel.SDK.Logs.LogRecordProcessor.config(),
          timeout :: timeout()
        ) :: :ok | {:error, term()}
  def shutdown(%{pid: pid}, timeout \\ @default_shutdown_timeout_ms) do
    :gen_statem.stop(pid, :normal, timeout)
  catch
    # `:gen_statem.stop/3` (via `:proc_lib.stop/3`) raises bare
    # `:noproc` / `:timeout` exits — different shape from
    # `:gen_statem.call/3`, which wraps both with an MFA tuple.
    :exit, :noproc -> :ok
    :exit, :timeout -> {:error, :timeout}
  end

  @doc """
  **SDK** (Simple implementation) — Forwards `force_flush/1`
  to the configured exporter. The processor itself buffers
  nothing beyond the gen_statem mailbox (each cast immediately
  triggers an export), but spec §LogRecordProcessor L484-L486
  makes it a built-in MUST to *"invoke ForceFlush on [the
  exporter]"* — the exporter may have its own buffering (HTTP
  keep-alive batching, OS write buffers, etc.).

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

  @spec start_link(config :: start_link_config()) :: :gen_statem.start_ret()
  def start_link(config) do
    :gen_statem.start_link(__MODULE__, config, [])
  end

  @impl :gen_statem
  @spec callback_mode() :: :state_functions
  def callback_mode, do: :state_functions

  @impl :gen_statem
  @spec init(config :: start_link_config()) :: {:ok, :running, State.t()}
  def init(config) do
    {exporter_module, exporter_opts} = Map.fetch!(config, :exporter)
    {:ok, exporter_state} = exporter_module.init(exporter_opts)
    {:ok, :running, %State{exporter: {exporter_module, exporter_state}}}
  end

  # --- State: :running ---

  @typedoc """
  Events the `:running` state handles.

  - `{:export, log_record}` arrives via `:gen_statem.cast/2`
    from `on_emit/3` — non-blocking enqueue + immediate export.
  - `:force_flush` arrives via `:gen_statem.call/3` from
    `force_flush/2` — synchronous exporter flush with reply.
  """
  @type running_event_content :: {:export, Otel.SDK.Logs.LogRecord.t()} | :force_flush

  @spec running(
          event_type :: :gen_statem.event_type(),
          event_content :: running_event_content(),
          state :: State.t()
        ) :: :gen_statem.event_handler_result(State.t())
  def running(:cast, {:export, log_record}, %State{exporter: {module, exporter_state}} = state) do
    module.export([log_record], exporter_state)
    {:keep_state, state}
  end

  def running({:call, from}, :force_flush, %State{exporter: {module, exporter_state}} = state) do
    result = module.force_flush(exporter_state)
    {:keep_state, state, [{:reply, from, result}]}
  end

  # --- terminate ---

  @impl :gen_statem
  @spec terminate(reason :: term(), state_name :: atom(), state :: State.t()) :: :ok
  def terminate(_reason, _state_name, %State{exporter: {module, exporter_state}}) do
    # Spec §LogRecordProcessor L469: "Shutdown MUST include the
    # effects of ForceFlush" — flush exporter buffers before
    # tearing it down. Runs for any exit path (`:gen_statem.stop`
    # from our `shutdown/2`, supervisor-initiated `:shutdown`,
    # uncaught crash with `terminate/3` invoked).
    module.force_flush(exporter_state)
    module.shutdown(exporter_state)
    :ok
  end
end
