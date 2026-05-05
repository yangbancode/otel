defmodule Otel.Metrics.MetricReader.PeriodicExporting do
  @moduledoc """
  A MetricReader that periodically collects metrics and exports
  them via a configured exporter.

  Export calls are serialized to prevent concurrent invocation.

  ## Lifecycle

  Application shutdown is delegated to OTP. `init/1` sets
  `trap_exit: true` so `Application.stop(:otel)` (or any
  supervisor termination signal) reaches `terminate/2`,
  which performs a final collect/export and calls the
  exporter's `shutdown/1`. There is no public `shutdown` API.
  """

  use GenServer

  @default_export_interval_ms 60_000

  @spec start_link(config :: Otel.Metrics.MetricReader.config() | []) :: GenServer.on_start()
  def start_link(config \\ %{}) do
    GenServer.start_link(__MODULE__, normalize(config), name: __MODULE__)
  end

  @spec normalize(config :: Otel.Metrics.MetricReader.config() | []) :: map()
  defp normalize([]), do: %{}
  defp normalize(map) when is_map(map), do: map

  @doc """
  **SDK** (test helper) — Triggers an immediate collect/export
  cycle and calls the exporter's `force_flush/1`.
  """
  @spec force_flush() :: :ok
  def force_flush do
    GenServer.call(__MODULE__, :force_flush)
  end

  @impl GenServer
  def init(config) do
    # `Otel.Application` supervises this child with `[]` config —
    # meter_config (ETS table refs, reader_id) comes from
    # `Otel.Metrics.meter_config/0`. Tests that want a custom
    # exporter or interval override via the args.
    Process.flag(:trap_exit, true)

    meter_config =
      Map.get_lazy(config, :meter_config, fn ->
        Otel.Metrics.meter_config()
      end)

    exporter = Map.get(config, :exporter, {Otel.Metrics.MetricExporter, %{}})

    interval = Map.get(config, :export_interval_ms, @default_export_interval_ms)
    timer_ref = schedule_collect(interval)

    state = %{
      meter_config: meter_config,
      exporter: init_exporter(exporter),
      export_interval_ms: interval,
      timer_ref: timer_ref
    }

    {:ok, state}
  end

  # Runs the exporter's own `init/1`; `:ignore` demotes to `nil`.
  @spec init_exporter({module(), term()} | nil) :: {module(), term()} | nil
  defp init_exporter(nil), do: nil

  defp init_exporter({module, opts}) do
    case module.init(opts) do
      {:ok, state} -> {module, state}
      :ignore -> nil
    end
  end

  @impl GenServer
  def handle_info(:collect, state) do
    do_collect_and_export(state)
    timer_ref = schedule_collect(state.export_interval_ms)
    {:noreply, %{state | timer_ref: timer_ref}}
  end

  @impl GenServer
  def handle_call(:force_flush, _from, state) do
    do_collect_and_export(state)
    call_exporter(state.exporter, :force_flush)
    {:reply, :ok, state}
  end

  def handle_call(:collect, _from, state) do
    metrics = Otel.Metrics.MetricReader.collect(state.meter_config)
    {:reply, {:ok, metrics}, state}
  end

  # Supervisor-driven termination (`Application.stop(:otel)` or any
  # `:shutdown` signal): cancel the periodic timer, perform a final
  # collect/export so metrics pending at termination still leave the
  # process, and call the exporter's `shutdown/1`. `trap_exit: true`
  # in `init/1` is what makes this run.
  #
  # The collect step invokes user-supplied observable callbacks, which
  # may raise (e.g. a callback referencing a `Process.info(pid, ...)`
  # whose pid died first under the supervisor's shutdown ordering).
  # We catch any such failure so that `exporter.shutdown` always runs
  # — `code-conventions.md` exempts lifecycle hooks from the
  # happy-path rule for exactly this case.
  @impl GenServer
  @spec terminate(reason :: term(), state :: map()) :: :ok
  def terminate(_reason, state) do
    Process.cancel_timer(state.timer_ref)

    try do
      do_collect_and_export(state)
    catch
      _kind, _reason -> :ok
    end

    call_exporter(state.exporter, :shutdown)
    :ok
  end

  @spec do_collect_and_export(state :: map()) :: :ok
  defp do_collect_and_export(state) do
    metrics = Otel.Metrics.MetricReader.collect(state.meter_config)

    case metrics do
      [] -> :ok
      batch -> call_exporter(state.exporter, {:export, batch})
    end
  end

  @spec call_exporter(exporter :: {module(), term()} | nil, message :: term()) :: term()
  defp call_exporter(nil, _message), do: :ok

  defp call_exporter({module, config}, {:export, batch}) do
    module.export(batch, config)
  end

  defp call_exporter({module, config}, :force_flush) do
    module.force_flush(config)
  end

  defp call_exporter({module, config}, :shutdown) do
    module.shutdown(config)
  end

  @spec schedule_collect(interval_ms :: pos_integer()) :: reference()
  defp schedule_collect(interval_ms) do
    Process.send_after(self(), :collect, interval_ms)
  end
end
