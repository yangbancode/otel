defmodule Otel.SDK.Metrics.PeriodicExportingMetricReader do
  @moduledoc """
  A MetricReader that periodically collects metrics and exports
  them via a configured exporter.

  Export calls are serialized to prevent concurrent invocation.
  """

  use GenServer

  @behaviour Otel.SDK.Metrics.MetricReader

  @default_export_interval_ms 60_000

  @impl Otel.SDK.Metrics.MetricReader
  @spec start_link(config :: map()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @impl Otel.SDK.Metrics.MetricReader
  @spec shutdown(server :: GenServer.server()) :: :ok | {:error, term()}
  def shutdown(server) do
    GenServer.call(server, :shutdown)
  end

  @impl Otel.SDK.Metrics.MetricReader
  @spec force_flush(server :: GenServer.server()) :: :ok | {:error, term()}
  def force_flush(server) do
    GenServer.call(server, :force_flush)
  end

  @impl GenServer
  def init(config) do
    interval = Map.get(config, :export_interval_ms, @default_export_interval_ms)
    timer_ref = schedule_collect(interval)

    state = %{
      meter_config: config.meter_config,
      exporter: config.exporter,
      export_interval_ms: interval,
      timer_ref: timer_ref,
      shut_down: false
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:collect, %{shut_down: true} = state) do
    {:noreply, state}
  end

  def handle_info(:collect, state) do
    do_collect_and_export(state)
    timer_ref = schedule_collect(state.export_interval_ms)
    {:noreply, %{state | timer_ref: timer_ref}}
  end

  @impl GenServer
  def handle_call(:shutdown, _from, %{shut_down: true} = state) do
    {:reply, {:error, :already_shut_down}, state}
  end

  def handle_call(:shutdown, _from, state) do
    Process.cancel_timer(state.timer_ref)
    do_collect_and_export(state)
    call_exporter(state.exporter, :shutdown)
    {:reply, :ok, %{state | shut_down: true}}
  end

  def handle_call(:force_flush, _from, %{shut_down: true} = state) do
    {:reply, {:error, :shut_down}, state}
  end

  def handle_call(:force_flush, _from, state) do
    do_collect_and_export(state)
    call_exporter(state.exporter, :force_flush)
    {:reply, :ok, state}
  end

  def handle_call(:collect, _from, %{shut_down: true} = state) do
    {:reply, {:error, :shut_down}, state}
  end

  def handle_call(:collect, _from, state) do
    metrics = Otel.SDK.Metrics.MetricReader.collect(state.meter_config)
    {:reply, {:ok, metrics}, state}
  end

  @spec do_collect_and_export(state :: map()) :: :ok
  defp do_collect_and_export(state) do
    metrics = Otel.SDK.Metrics.MetricReader.collect(state.meter_config)

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
