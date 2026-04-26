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

  Spec L526 — the only configurable parameter is `exporter`;
  this implementation also accepts an optional `:name` for
  registering the gen_statem.

  ## Synchronous emit trade-off

  Spec §LogRecordProcessor L397 says *"OnEmit ... SHOULD NOT
  block or throw exceptions"*, but §Simple processor L516-L519
  mandates *"as soon as they are finished"* synchronous export.
  The Simple processor takes the trade-off explicitly:
  `on_emit/3` blocks the calling process via
  `:gen_statem.call/2` until the exporter returns. Use
  `Otel.SDK.Logs.LogRecordProcessor.Batch` when non-blocking
  emit is required.

  ## State model and shutdown

  One `:gen_statem` state, `:running`. The processor accepts
  `:export` and `:force_flush` requests there. Shutdown
  terminates the gen_statem rather than transitioning to a
  parked state — `shutdown/1` calls
  `:gen_statem.stop(__MODULE__, :normal, :infinity)`, which
  invokes `terminate/3` (where the exporter's `force_flush/1`
  and `shutdown/1` run, satisfying spec L469
  *"Shutdown MUST include the effects of ForceFlush"*) and
  then exits the process cleanly.

  Late-arriving requests after termination — `on_emit/3`,
  `force_flush/1`, or a second `shutdown/1` — fail the
  underlying `:gen_statem.call/2` with `:exit, {:noproc, _}`.
  Each behaviour callback catches that and returns `:ok`,
  satisfying spec §LogRecordProcessor L463 *"SDKs SHOULD
  ignore these calls gracefully"*.

  Supervisor `restart: :transient` ensures the process is
  not restarted after a `:normal` (shutdown-initiated) or
  `:shutdown` (supervisor-initiated) exit, while still
  restarting on abnormal crashes.

  When the day comes that we want hung-exporter timeout
  isolation, an additional `:exporting` state with a runner
  process would slot in here cleanly. For now, single state.

  ## Public API

  | Function | Role |
  |---|---|
  | `on_emit/3`, `enabled?/3`, `shutdown/1`, `force_flush/1` | **SDK** (Simple implementation) |
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
  - `:name` (**optional**) — the registered atom for the
    gen_statem. Defaults to `__MODULE__`. Provide a unique name
    to run multiple Simple processors with different exporters
    in the same BEAM node.
  """
  @type start_link_config :: %{
          required(:exporter) => {module(), term()},
          optional(:name) => atom()
        }

  # --- LogRecordProcessor callbacks ---

  @doc """
  **SDK** (Simple implementation) — Hand the emitted record to
  the gen_statem for serialised export
  (`logs/sdk.md` §Simple processor L516-L519). Returns `:ok`
  silently when the gen_statem has already terminated, per
  spec L463.
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec on_emit(
          log_record :: Otel.SDK.Logs.LogRecord.t(),
          ctx :: Otel.API.Ctx.t(),
          config :: Otel.SDK.Logs.LogRecordProcessor.config()
        ) :: :ok
  def on_emit(log_record, _ctx, %{reg_name: reg_name}) do
    :gen_statem.call(reg_name, {:export, log_record})
  catch
    # `:gen_statem.call/2` to a dead/unregistered atom raises
    # `exit({:noproc, mfa})` via `:gen.do_for_proc/2`.
    :exit, {:noproc, _} -> :ok
  end

  @doc """
  **SDK** (Simple implementation) — Always returns `true`; the
  Simple processor has no filtering policy of its own
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
  **SDK** (Simple implementation) — Synchronously stop the
  gen_statem via `:gen_statem.stop/3`. The `terminate/3`
  callback runs the exporter's `force_flush/1` then
  `shutdown/1` (spec L469) before the process exits. Returns
  `:ok` silently when the gen_statem has already terminated,
  per spec L463 (covers idempotent re-entry from a duplicate
  `shutdown/1`).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec shutdown(config :: Otel.SDK.Logs.LogRecordProcessor.config()) :: :ok
  def shutdown(%{reg_name: reg_name}) do
    :gen_statem.stop(reg_name, :normal, :infinity)
  catch
    # `:gen_statem.stop/3` (via `:gen.stop/3`) raises bare
    # `exit(noproc)` for a dead/unregistered atom — different
    # shape from `:gen_statem.call/2` which wraps in a tuple.
    :exit, :noproc -> :ok
  end

  @doc """
  **SDK** (Simple implementation) — Forwards `force_flush/1`
  to the configured exporter. The processor itself has no
  buffer (synchronous emit), but spec §LogRecordProcessor
  L484-L486 makes it a built-in MUST to *"invoke ForceFlush
  on [the exporter]"* — the exporter may have its own
  buffering (HTTP keep-alive batching, OS write buffers, etc.).
  Returns `:ok` silently when the gen_statem has already
  terminated, per spec L463.
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec force_flush(config :: Otel.SDK.Logs.LogRecordProcessor.config()) ::
          :ok | {:error, term()}
  def force_flush(%{reg_name: reg_name}) do
    :gen_statem.call(reg_name, :force_flush)
  catch
    :exit, {:noproc, _} -> :ok
  end

  # --- gen_statem lifecycle ---

  @spec child_spec(arg :: term()) :: Supervisor.child_spec()
  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]},
      type: :worker,
      restart: :transient
      # `:shutdown` omitted — `:worker` default 5000ms gives
      # `terminate/3` (which calls exporter's `force_flush/1` +
      # `shutdown/1`) enough time to complete an OTLP HTTP final
      # flush, satisfying spec §LogRecordProcessor L469/L471.
    }
  end

  @spec start_link(config :: start_link_config()) :: :gen_statem.start_ret()
  def start_link(config) do
    name = Map.get(config, :name, __MODULE__)
    :gen_statem.start_link({:local, name}, __MODULE__, config, [])
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

  @spec running(
          event_type :: :gen_statem.event_type(),
          event_content :: term(),
          state :: State.t()
        ) :: :gen_statem.event_handler_result(State.t())
  def running(
        {:call, from},
        {:export, log_record},
        %State{exporter: {module, exporter_state}} = state
      ) do
    module.export([log_record], exporter_state)
    {:keep_state, state, [{:reply, from, :ok}]}
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
    # from our `shutdown/1`, supervisor-initiated `:shutdown`,
    # uncaught crash with `terminate/3` invoked).
    module.force_flush(exporter_state)
    module.shutdown(exporter_state)
    :ok
  end
end
