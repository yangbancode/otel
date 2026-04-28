defmodule Otel.SDK.Trace.SpanProcessor.Batch do
  @moduledoc """
  BatchSpanProcessor that accumulates spans and exports in
  batches (`trace/sdk.md` §Batching processor L1086-L1118).

  Exports are triggered by a timer, queue size threshold, or
  force_flush. Uses a GenServer to serialize export calls
  (spec L1146-L1147 — *"Export() should not be called
  concurrently with other Export calls for the same exporter
  instance"*).

  ## Public API

  | Function | Role |
  |---|---|
  | `start_link/1` | **SDK** (lifecycle) |
  | `on_start/3`, `on_end/2`, `shutdown/1`, `force_flush/1` | **SDK** (Batch implementation) |

  ## References

  - OTel Trace SDK §Batching processor: `opentelemetry-specification/specification/trace/sdk.md` L1086-L1118
  - Parent behaviour: `Otel.SDK.Trace.SpanProcessor`
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
  def on_end(span, %{pid: pid}) do
    if Bitwise.band(span.trace_flags, 1) != 0 do
      GenServer.cast(pid, {:add_span, span})
      :ok
    else
      :dropped
    end
  end

  @spec shutdown(config :: Otel.SDK.Trace.SpanProcessor.config(), timeout :: timeout()) ::
          :ok | {:error, term()}
  @impl Otel.SDK.Trace.SpanProcessor
  def shutdown(%{pid: pid}, timeout \\ @default_export_timeout_ms) do
    GenServer.call(pid, :shutdown, timeout)
  catch
    :exit, {:noproc, _} -> {:error, :already_shutdown}
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  @spec force_flush(config :: Otel.SDK.Trace.SpanProcessor.config(), timeout :: timeout()) ::
          :ok | {:error, term()}
  @impl Otel.SDK.Trace.SpanProcessor
  def force_flush(%{pid: pid}, timeout \\ @default_export_timeout_ms) do
    GenServer.call(pid, :force_flush, timeout)
  catch
    :exit, {:noproc, _} -> {:error, :already_shutdown}
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  # --- GenServer ---

  @spec start_link(config :: Otel.SDK.Trace.SpanProcessor.config()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @impl GenServer
  @spec init(config :: Otel.SDK.Trace.SpanProcessor.config()) :: {:ok, map()}
  def init(config) do
    scheduled_delay = Map.get(config, :scheduled_delay_ms, @default_scheduled_delay_ms)

    state = %{
      exporter: Otel.SDK.Exporter.Init.call(Map.fetch!(config, :exporter)),
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
        {:noreply, export_batch(new_state)}
      else
        {:noreply, new_state}
      end
    end
  end

  @impl GenServer
  @spec handle_call(msg :: term(), from :: GenServer.from(), state :: map()) ::
          {:reply, term(), map()}
  def handle_call(:force_flush, _from, state) do
    new_state = export_batch(state)

    case new_state.exporter do
      {module, exporter_state} -> module.force_flush(exporter_state)
      nil -> :ok
    end

    {:reply, :ok, new_state}
  end

  def handle_call(:shutdown, _from, state) do
    new_state = export_batch(state)

    case new_state.exporter do
      {module, exporter_state} -> module.shutdown(exporter_state)
      nil -> :ok
    end

    {:reply, :ok, %{new_state | exporter: nil}}
  end

  @impl GenServer
  @spec handle_info(msg :: term(), state :: map()) :: {:noreply, map()}
  def handle_info(:export_timer, state) do
    new_state = export_batch(state)
    schedule_export(state.scheduled_delay_ms)
    {:noreply, new_state}
  end

  # Spec `trace/sdk.md` L1113 — *"exportTimeoutMillis: how long
  # the export can run before it is cancelled. The default value
  # is 30000."* and L1156 *"Export() MUST NOT block indefinitely,
  # there MUST be a reasonable upper limit"*.
  #
  # We enforce the bound at *between-batch* granularity:
  # `export_batch/1` computes an absolute deadline at entry and
  # `export_until/2` checks it before draining each batch.
  # When the deadline elapses partway through a multi-batch
  # drain, the remaining spans stay in the queue for the next
  # export trigger (timer, force_flush, shutdown). The
  # individual `exporter.export/3` call itself is synchronous
  # and not preempted — the spec MUST about indefinite blocking
  # is the exporter's contract to satisfy (L1156).
  @spec export_batch(state :: map()) :: map()
  defp export_batch(state) do
    deadline = System.monotonic_time(:millisecond) + state.export_timeout_ms
    export_until(state, deadline)
  end

  @spec export_until(state :: map(), deadline :: integer()) :: map()
  defp export_until(%{queue: [], queue_size: 0} = state, _deadline), do: state

  defp export_until(%{exporter: nil} = state, _deadline) do
    %{state | queue: [], queue_size: 0}
  end

  defp export_until(state, deadline) do
    if System.monotonic_time(:millisecond) < deadline do
      {batch, remaining} = Enum.split(state.queue, state.max_export_batch_size)
      {exporter_module, exporter_state} = state.exporter
      exporter_module.export(Enum.reverse(batch), state.resource, exporter_state)
      new_state = %{state | queue: remaining, queue_size: length(remaining)}
      export_until(new_state, deadline)
    else
      state
    end
  end

  @spec schedule_export(delay_ms :: non_neg_integer()) :: reference()
  defp schedule_export(delay_ms) do
    Process.send_after(self(), :export_timer, delay_ms)
  end
end
