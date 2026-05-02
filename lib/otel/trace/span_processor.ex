defmodule Otel.Trace.SpanProcessor do
  @moduledoc """
  Hardcoded BatchSpanProcessor — the only SpanProcessor this
  SDK ships.

  Accumulates spans and exports in batches
  (`trace/sdk.md` §Batching processor L1086-L1118). Exports
  are triggered by a timer, queue size threshold, or
  `force_flush`. Uses a GenServer to serialize export calls
  (spec L1146-L1147 — *"Export() should not be called
  concurrently with other Export calls for the same exporter
  instance"*).

  The behaviour abstraction (and a separate `Batch` impl
  module) was collapsed because the SDK ships only this
  processor and users cannot substitute their own (per
  minikube-style scope). The spec also defines a `Simple`
  processor (`trace/sdk.md` L1070-L1081), intentionally
  omitted — Simple has no overload protection (every span
  end is a synchronous export call), making it dangerous on
  BEAM under slow exporters.

  ## Public API

  | Function | Role |
  |---|---|
  | `start_link/1` | **SDK** (lifecycle) |
  | `on_start/3` | **SDK** (OTel API MUST) — `trace/sdk.md` L963-L982 |
  | `on_end/2` | **SDK** (OTel API MUST) — `trace/sdk.md` L1005-L1027 |
  | `shutdown/2` | **SDK** (OTel API MUST) — `trace/sdk.md` §Shutdown |
  | `force_flush/2` | **SDK** (OTel API MUST) — `trace/sdk.md` §ForceFlush |

  ## Deferred Development-status features

  - **OnEnding callback.** Spec `trace/sdk.md` L959-L961 +
    L983-L1003 (Status: Development) describes an `OnEnding`
    method called *during* `Span.End()` — after the end
    timestamp is computed but before the span becomes
    immutable. The hook lets processors apply last-moment
    mutations (`SetAttribute`, `AddEvent`, `AddLink`)
    synchronously before any `OnEnd` fires. Not implemented:
    `Otel.Trace.Span` transitions directly from end-time
    computation to `take/1` (storage removal) without
    invoking processors mid-flight. Waits for spec
    stabilisation.

  ## References

  - OTel Trace SDK §SpanProcessor: `opentelemetry-specification/specification/trace/sdk.md` L946-L1075
  - OTel Trace SDK §Batching processor: `opentelemetry-specification/specification/trace/sdk.md` L1086-L1118
  """

  use GenServer

  @type config :: term()

  # Hardcoded batch knobs — the SDK ships only these values and
  # users cannot override them (per minikube-style scope). Numbers
  # follow the spec defaults at `trace/sdk.md` L1109-L1118.
  @max_queue_size 2048
  @scheduled_delay_ms 5000
  @export_timeout_ms 30_000
  @max_export_batch_size 512

  # --- Public API ---

  @doc """
  Called when a span is started. Must not block or throw.
  Returns the (possibly modified) span.
  """
  @spec on_start(
          ctx :: Otel.Ctx.t(),
          span :: Otel.Trace.Span.t(),
          config :: config()
        ) :: Otel.Trace.Span.t()
  def on_start(_ctx, span, _config), do: span

  @doc """
  Called after a span is ended. Must not block or throw.
  """
  @spec on_end(span :: Otel.Trace.Span.t(), config :: config()) ::
          :ok | :dropped | {:error, term()}
  def on_end(span, %{pid: pid}) do
    if Bitwise.band(span.trace_flags, 1) != 0 do
      GenServer.cast(pid, {:add_span, span})
      :ok
    else
      :dropped
    end
  end

  @doc """
  Shuts down the processor. Includes the effects of
  `force_flush/2`. `timeout` is the upper bound the
  processor honours for the whole shutdown sequence per
  `trace/sdk.md` §Shutdown.
  """
  @spec shutdown(config :: config(), timeout :: timeout()) :: :ok | {:error, term()}
  def shutdown(%{pid: pid}, timeout \\ @export_timeout_ms) do
    GenServer.call(pid, :shutdown, timeout)
  catch
    :exit, {:noproc, _} -> {:error, :already_shutdown}
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  @doc """
  Forces the processor to export all pending spans
  immediately. `timeout` bounds the wait per
  `trace/sdk.md` §ForceFlush.
  """
  @spec force_flush(config :: config(), timeout :: timeout()) :: :ok | {:error, term()}
  def force_flush(%{pid: pid}, timeout \\ @export_timeout_ms) do
    GenServer.call(pid, :force_flush, timeout)
  catch
    :exit, {:noproc, _} -> {:error, :already_shutdown}
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  # --- GenServer ---

  @spec start_link(config :: config()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @impl GenServer
  @spec init(config :: config()) :: {:ok, map()}
  def init(config) do
    state = %{
      exporter: Otel.SDK.Exporter.Init.call(Map.fetch!(config, :exporter)),
      resource: Map.get(config, :resource, %{}),
      queue: [],
      queue_size: 0
    }

    schedule_export()
    {:ok, state}
  end

  @impl GenServer
  @spec handle_cast(msg :: term(), state :: map()) :: {:noreply, map()}
  def handle_cast({:add_span, span}, state) do
    if state.queue_size >= @max_queue_size do
      {:noreply, state}
    else
      new_state = %{state | queue: [span | state.queue], queue_size: state.queue_size + 1}

      if new_state.queue_size >= @max_export_batch_size do
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
    schedule_export()
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
    deadline = System.monotonic_time(:millisecond) + @export_timeout_ms
    export_until(state, deadline)
  end

  @spec export_until(state :: map(), deadline :: integer()) :: map()
  defp export_until(%{queue: [], queue_size: 0} = state, _deadline), do: state

  defp export_until(%{exporter: nil} = state, _deadline) do
    %{state | queue: [], queue_size: 0}
  end

  defp export_until(state, deadline) do
    if System.monotonic_time(:millisecond) < deadline do
      {batch, remaining} = Enum.split(state.queue, @max_export_batch_size)
      {exporter_module, exporter_state} = state.exporter
      exporter_module.export(Enum.reverse(batch), state.resource, exporter_state)
      new_state = %{state | queue: remaining, queue_size: length(remaining)}
      export_until(new_state, deadline)
    else
      state
    end
  end

  @spec schedule_export() :: reference()
  defp schedule_export do
    Process.send_after(self(), :export_timer, @scheduled_delay_ms)
  end
end
