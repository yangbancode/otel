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
  emit through the GenServer's `handle_call/3`, which is
  inherently serial per-process.

  Spec L526 — the only configurable parameter is `exporter`;
  this implementation also accepts an optional `:name` for
  registering the GenServer.

  ## Synchronous emit trade-off

  Spec §LogRecordProcessor L397 says *"OnEmit ... SHOULD NOT
  block or throw exceptions"*, but §Simple processor L516-L519
  mandates *"as soon as they are finished"* synchronous export.
  The Simple processor takes the trade-off explicitly:
  `on_emit/3` blocks the calling process via `GenServer.call/2`
  until the exporter returns. Use
  `Otel.SDK.Logs.LogRecordProcessor.Batch` when non-blocking
  emit is required.

  ## Public API

  | Function | Role |
  |---|---|
  | `on_emit/3`, `enabled?/3`, `shutdown/1`, `force_flush/1` | **SDK** (Simple implementation) |
  | `start_link/1` | **SDK** (lifecycle) |

  ## References

  - OTel Logs SDK Simple processor: `opentelemetry-specification/specification/logs/sdk.md` §Simple processor
  - Parent behaviour: `Otel.SDK.Logs.LogRecordProcessor`
  """

  use GenServer

  @behaviour Otel.SDK.Logs.LogRecordProcessor

  # --- LogRecordProcessor callbacks ---

  @doc """
  **SDK** (Simple implementation) — Hand the emitted record to
  the GenServer for serialised export
  (`logs/sdk.md` §Simple processor L516-L519).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec on_emit(
          log_record :: Otel.SDK.Logs.LogRecord.t(),
          ctx :: Otel.API.Ctx.t(),
          config :: Otel.SDK.Logs.LogRecordProcessor.config()
        ) :: :ok
  def on_emit(log_record, _ctx, %{reg_name: reg_name}) do
    GenServer.call(reg_name, {:export, log_record})
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
  **SDK** (Simple implementation) — Shut down the GenServer,
  cascading to the exporter's `shutdown/1`. Returns
  `{:error, :already_shut_down}` on a second call so callers
  can distinguish idempotency from real failure
  (`logs/sdk.md` §LogRecordProcessor L457-L474).
  """
  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec shutdown(config :: Otel.SDK.Logs.LogRecordProcessor.config()) :: :ok | {:error, term()}
  def shutdown(%{reg_name: reg_name}) do
    GenServer.call(reg_name, :shutdown)
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
    GenServer.call(reg_name, :force_flush)
  end

  # --- GenServer lifecycle ---

  @spec start_link(config :: map()) :: GenServer.on_start()
  def start_link(config) do
    name = Map.get(config, :name, __MODULE__)
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @impl GenServer
  @spec init(config :: map()) :: {:ok, map()}
  def init(config) do
    name = Map.get(config, :name, __MODULE__)
    {exporter_module, exporter_opts} = Map.fetch!(config, :exporter)
    exporter = init_exporter(exporter_module, exporter_opts)

    {:ok, %{exporter: exporter, name: name, shut_down: false}}
  end

  @impl GenServer
  @spec handle_call(msg :: term(), from :: GenServer.from(), state :: map()) ::
          {:reply, term(), map()}
  def handle_call({:export, _log_record}, _from, %{exporter: nil} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:export, _log_record}, _from, %{shut_down: true} = state) do
    {:reply, :ok, state}
  end

  def handle_call(
        {:export, log_record},
        _from,
        %{exporter: {module, exporter_state}} = state
      ) do
    module.export([log_record], exporter_state)
    {:reply, :ok, state}
  end

  def handle_call(:shutdown, _from, %{shut_down: true} = state) do
    {:reply, {:error, :already_shut_down}, state}
  end

  def handle_call(:shutdown, _from, %{exporter: nil} = state) do
    {:reply, :ok, %{state | shut_down: true}}
  end

  def handle_call(:shutdown, _from, %{exporter: {module, exporter_state}} = state) do
    # Spec §LogRecordProcessor L469: "Shutdown MUST include the
    # effects of ForceFlush" — flush exporter buffers before
    # tearing it down.
    module.force_flush(exporter_state)
    module.shutdown(exporter_state)
    {:reply, :ok, %{state | exporter: nil, shut_down: true}}
  end

  def handle_call(:force_flush, _from, %{exporter: nil} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:force_flush, _from, %{exporter: {module, exporter_state}} = state) do
    result = module.force_flush(exporter_state)
    {:reply, result, state}
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
