defmodule Otel.Metrics.MetricReader.PeriodicExporting do
  @moduledoc """
  A MetricReader that periodically collects metrics and exports
  them via a configured exporter.

  Export calls are serialized to prevent concurrent invocation.
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

  @spec shutdown() :: :ok | {:error, term()}
  def shutdown do
    GenServer.call(__MODULE__, :shutdown)
  catch
    :exit, {:noproc, _} -> {:error, :already_shutdown}
  end

  @spec force_flush() :: :ok | {:error, term()}
  def force_flush do
    GenServer.call(__MODULE__, :force_flush)
  catch
    :exit, {:noproc, _} -> {:error, :already_shutdown}
  end

  @impl GenServer
  def init(config) do
    # `Otel.SDK.Application` supervises this child with `[]` config
    # — meter_config (ETS table refs, reader_id) is seeded by
    # `Otel.Metrics.MeterProvider.init/0` and read from
    # persistent_term here. Tests that want a custom exporter or
    # interval override via the args.
    meter_config =
      Map.get_lazy(config, :meter_config, fn ->
        Otel.Metrics.MeterProvider.reader_meter_config()
      end)

    exporter =
      Map.get_lazy(config, :exporter, fn -> Otel.SDK.Config.exporter(:metrics) end)

    interval = Map.get(config, :export_interval_ms, @default_export_interval_ms)
    timer_ref = schedule_collect(interval)

    state = %{
      meter_config: meter_config,
      exporter: Otel.SDK.Exporter.Init.call(exporter),
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
    {:reply, {:error, :already_shutdown}, state}
  end

  def handle_call(:shutdown, _from, state) do
    Process.cancel_timer(state.timer_ref)
    do_collect_and_export(state)
    call_exporter(state.exporter, :shutdown)
    {:reply, :ok, %{state | shut_down: true}}
  end

  def handle_call(:force_flush, _from, %{shut_down: true} = state) do
    {:reply, {:error, :already_shutdown}, state}
  end

  def handle_call(:force_flush, _from, state) do
    do_collect_and_export(state)
    call_exporter(state.exporter, :force_flush)
    {:reply, :ok, state}
  end

  def handle_call(:collect, _from, %{shut_down: true} = state) do
    {:reply, {:error, :already_shutdown}, state}
  end

  def handle_call(:collect, _from, state) do
    metrics = Otel.Metrics.MetricReader.collect(state.meter_config)
    {:reply, {:ok, metrics}, state}
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
