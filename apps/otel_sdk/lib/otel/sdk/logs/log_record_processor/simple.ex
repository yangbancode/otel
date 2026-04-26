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

  ## State model

  Two `:gen_statem` states make the processor's lifecycle
  explicit:

  - `:running` — accepts `:export`, `:force_flush`, and
    `:shutdown` requests. The first `:shutdown` transitions
    here to `:shut_down`.
  - `:shut_down` — terminal. Subsequent `:export` and
    `:force_flush` are no-ops (per spec L462-L464 *"SDKs
    SHOULD ignore these calls gracefully"*); a second
    `:shutdown` returns `{:error, :already_shut_down}` so
    callers can distinguish idempotent re-entry from real
    failure.

  No `:exporting` intermediate state — export runs inline in
  the `:running` state callback because the spec mandates
  synchronous semantics; there is nothing for the gen_statem
  to do *between* receiving the request and replying. (When
  the day comes that we want hung-exporter timeout isolation,
  a third `:exporting` state with a runner process would slot
  in here cleanly.)

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

  # --- LogRecordProcessor callbacks ---

  @doc """
  **SDK** (Simple implementation) — Hand the emitted record to
  the gen_statem for serialised export
  (`logs/sdk.md` §Simple processor L516-L519).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec on_emit(
          log_record :: Otel.SDK.Logs.LogRecord.t(),
          ctx :: Otel.API.Ctx.t(),
          config :: Otel.SDK.Logs.LogRecordProcessor.config()
        ) :: :ok
  def on_emit(log_record, _ctx, %{reg_name: reg_name}) do
    :gen_statem.call(reg_name, {:export, log_record})
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
  **SDK** (Simple implementation) — Transition to `:shut_down`
  and cascade to the exporter's `force_flush/1` then
  `shutdown/1`. Returns `{:error, :already_shut_down}` on a
  second call so callers can distinguish idempotency from
  real failure (`logs/sdk.md` §LogRecordProcessor L457-L474).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec shutdown(config :: Otel.SDK.Logs.LogRecordProcessor.config()) :: :ok | {:error, term()}
  def shutdown(%{reg_name: reg_name}) do
    :gen_statem.call(reg_name, :shutdown)
  end

  @doc """
  **SDK** (Simple implementation) — Forwards `force_flush/1`
  to the configured exporter. The processor itself has no
  buffer (synchronous emit), but spec §LogRecordProcessor
  L484-L486 makes it a built-in MUST to *"invoke ForceFlush
  on [the exporter]"* — the exporter may have its own
  buffering (HTTP keep-alive batching, OS write buffers, etc.).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec force_flush(config :: Otel.SDK.Logs.LogRecordProcessor.config()) ::
          :ok | {:error, term()}
  def force_flush(%{reg_name: reg_name}) do
    :gen_statem.call(reg_name, :force_flush)
  end

  # --- gen_statem lifecycle ---

  @spec child_spec(arg :: term()) :: Supervisor.child_spec()
  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @spec start_link(config :: map()) :: :gen_statem.start_ret()
  def start_link(config) do
    name = Map.get(config, :name, __MODULE__)
    :gen_statem.start_link({:local, name}, __MODULE__, config, [])
  end

  @impl :gen_statem
  @spec callback_mode() :: :state_functions
  def callback_mode, do: :state_functions

  @impl :gen_statem
  @spec init(config :: map()) :: {:ok, :running, map()}
  def init(config) do
    {exporter_module, exporter_opts} = Map.fetch!(config, :exporter)
    exporter = init_exporter(exporter_module, exporter_opts)
    {:ok, :running, %{exporter: exporter}}
  end

  # --- State: :running ---

  @spec running(
          event_type :: :gen_statem.event_type(),
          event_content :: term(),
          data :: map()
        ) :: :gen_statem.event_handler_result(map())
  def running({:call, from}, {:export, _log_record}, %{exporter: nil} = data) do
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def running(
        {:call, from},
        {:export, log_record},
        %{exporter: {module, exporter_state}} = data
      ) do
    module.export([log_record], exporter_state)
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def running({:call, from}, :force_flush, %{exporter: nil} = data) do
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def running({:call, from}, :force_flush, %{exporter: {module, exporter_state}} = data) do
    result = module.force_flush(exporter_state)
    {:keep_state, data, [{:reply, from, result}]}
  end

  def running({:call, from}, :shutdown, %{exporter: nil} = data) do
    {:next_state, :shut_down, data, [{:reply, from, :ok}]}
  end

  def running({:call, from}, :shutdown, %{exporter: {module, exporter_state}} = data) do
    # Spec §LogRecordProcessor L469: "Shutdown MUST include the
    # effects of ForceFlush" — flush exporter buffers before
    # tearing it down.
    module.force_flush(exporter_state)
    module.shutdown(exporter_state)
    {:next_state, :shut_down, %{data | exporter: nil}, [{:reply, from, :ok}]}
  end

  # --- State: :shut_down ---

  @spec shut_down(
          event_type :: :gen_statem.event_type(),
          event_content :: term(),
          data :: map()
        ) :: :gen_statem.event_handler_result(map())
  def shut_down({:call, from}, {:export, _log_record}, data) do
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def shut_down({:call, from}, :force_flush, data) do
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def shut_down({:call, from}, :shutdown, data) do
    {:keep_state, data, [{:reply, from, {:error, :already_shut_down}}]}
  end

  # --- Private ---

  @spec init_exporter(module :: module(), opts :: term()) ::
          {module(), Otel.SDK.Logs.LogRecordExporter.state()} | nil
  defp init_exporter(module, opts) do
    case module.init(opts) do
      {:ok, state} -> {module, state}
      :ignore -> nil
    end
  end
end
