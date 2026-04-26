defmodule Otel.SDK.Trace.SpanProcessor.Batch do
  @moduledoc """
  BatchSpanProcessor that accumulates spans and exports in batches.

  Exports are triggered by a timer, queue size threshold, or
  force_flush. Uses a GenServer to serialize export calls (L1089).
  """

  use GenServer

  @behaviour Otel.SDK.Trace.SpanProcessor

  @default_max_queue_size 2048
  @default_scheduled_delay_ms 5000
  @default_export_timeout_ms 30_000
  @default_max_export_batch_size 512

  # --- SpanProcessor callbacks ---

  @spec on_start(
          ctx :: Otel.API.Ctx.t(),
          span :: Otel.SDK.Trace.Span.t(),
          config :: Otel.SDK.Trace.SpanProcessor.config()
        ) :: Otel.SDK.Trace.Span.t()
  @impl Otel.SDK.Trace.SpanProcessor
  def on_start(_ctx, span, _config), do: span

  @spec on_end(
          span :: Otel.SDK.Trace.Span.t(),
          config :: Otel.SDK.Trace.SpanProcessor.config()
        ) :: :ok | :dropped | {:error, term()}
  @impl Otel.SDK.Trace.SpanProcessor
  def on_end(span, %{reg_name: reg_name}) do
    if Bitwise.band(span.trace_flags, 1) != 0 do
      GenServer.cast(reg_name, {:add_span, span})
      :ok
    else
      :dropped
    end
  end

  @spec shutdown(config :: Otel.SDK.Trace.SpanProcessor.config()) :: :ok | {:error, term()}
  @impl Otel.SDK.Trace.SpanProcessor
  def shutdown(%{reg_name: reg_name}) do
    GenServer.call(reg_name, :shutdown)
  end

  @spec force_flush(config :: Otel.SDK.Trace.SpanProcessor.config()) :: :ok | {:error, term()}
  @impl Otel.SDK.Trace.SpanProcessor
  def force_flush(%{reg_name: reg_name}) do
    GenServer.call(reg_name, :force_flush)
  end

  # --- GenServer ---

  @spec start_link(config :: Otel.SDK.Trace.SpanProcessor.config()) :: GenServer.on_start()
  def start_link(config) do
    name = Map.get(config, :name, __MODULE__)
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @impl GenServer
  @spec init(config :: Otel.SDK.Trace.SpanProcessor.config()) :: {:ok, map()}
  def init(config) do
    {exporter_module, exporter_opts} = Map.fetch!(config, :exporter)

    scheduled_delay = Map.get(config, :scheduled_delay_ms, @default_scheduled_delay_ms)

    exporter =
      case exporter_module.init(exporter_opts) do
        {:ok, state} -> {exporter_module, state}
        :ignore -> nil
      end

    state = %{
      exporter: exporter,
      resource: Map.get(config, :resource, %{}),
      queue: [],
      queue_size: 0,
      max_queue_size: Map.get(config, :max_queue_size, @default_max_queue_size),
      scheduled_delay_ms: scheduled_delay,
      export_timeout_ms: Map.get(config, :export_timeout_ms, @default_export_timeout_ms),
      max_export_batch_size:
        Map.get(config, :max_export_batch_size, @default_max_export_batch_size)
    }

    schedule_export(scheduled_delay)
    {:ok, state}
  end

  @impl GenServer
  @spec handle_cast(msg :: term(), state :: map()) :: {:noreply, map()}
  def handle_cast({:add_span, span}, state) do
    if state.queue_size >= state.max_queue_size do
      {:noreply, state}
    else
      new_state = %{state | queue: [span | state.queue], queue_size: state.queue_size + 1}

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
  def handle_call(:force_flush, _from, state) do
    {:reply, :ok, do_export(state)}
  end

  def handle_call(:shutdown, _from, state) do
    new_state = do_export(state)

    case new_state.exporter do
      {module, exporter_state} -> module.shutdown(exporter_state)
      nil -> :ok
    end

    {:reply, :ok, %{new_state | exporter: nil}}
  end

  @impl GenServer
  @spec handle_info(msg :: term(), state :: map()) :: {:noreply, map()}
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
    exporter_module.export(Enum.reverse(batch), state.resource, exporter_state)
    new_state = %{state | queue: remaining, queue_size: length(remaining)}
    do_export(new_state)
  end

  @spec schedule_export(delay_ms :: non_neg_integer()) :: reference()
  defp schedule_export(delay_ms) do
    Process.send_after(self(), :export_timer, delay_ms)
  end
end
