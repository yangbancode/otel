defmodule Otel.Trace.SpanProcessor do
  @moduledoc """
  Hardcoded BatchSpanProcessor — the only SpanProcessor this
  SDK ships.

  Accumulates spans and exports in batches
  (`trace/sdk.md` §Batching processor L1086-L1118). Exports
  are triggered by a timer, queue size threshold,
  `force_flush`, or supervisor-driven termination. Uses a
  GenServer to serialize export calls (spec L1146-L1147 —
  *"Export() should not be called concurrently with other
  Export calls for the same exporter instance"*).

  The behaviour abstraction (and a separate `Batch` impl
  module) was collapsed because the SDK ships only this
  processor and users cannot substitute their own (per
  minikube-style scope). The spec also defines a `Simple`
  processor (`trace/sdk.md` L1070-L1081), intentionally
  omitted — Simple has no overload protection (every span
  end is a synchronous export call), making it dangerous on
  BEAM under slow exporters.

  ## Lifecycle

  Application shutdown is delegated to OTP. `init/1` sets
  `trap_exit: true` so `Application.stop(:otel)` (or any
  supervisor termination signal) reaches `terminate/2`,
  which drains the queue and calls the exporter's
  `shutdown/1`. There is no public `shutdown` API.

  ## Public API

  | Function | Role |
  |---|---|
  | `start_link/1` | **SDK** (lifecycle) |
  | `on_end/1` | **SDK** (OTel API MUST) — `trace/sdk.md` L1005-L1027 |
  | `force_flush/1` | **SDK** (test helper) — drains the queue and calls the exporter's `force_flush` |

  `on_start/3` (spec `trace/sdk.md` L963-L982) is a no-op for
  the Batch processor and is omitted — `Tracer.start_span`
  inserts directly into ETS without dispatch.

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
  Called when a span is ended. Must not block or throw.
  Sampled spans are queued for export; unsampled spans are
  dropped. The processor GenServer is registered under
  `__MODULE__`, so dispatch goes through the global name —
  if the GenServer isn't running (e.g. after shutdown), the
  cast is silently dropped.
  """
  @spec on_end(span :: Otel.Trace.Span.t()) :: :ok | :dropped
  def on_end(span) do
    if Bitwise.band(span.trace_flags, 1) != 0 do
      GenServer.cast(__MODULE__, {:add_span, span})
      :ok
    else
      :dropped
    end
  end

  @doc """
  Forces the processor to export all pending spans
  immediately. `timeout` bounds the wait per
  `trace/sdk.md` §ForceFlush.
  """
  @spec force_flush(timeout :: timeout()) :: :ok | {:error, term()}
  def force_flush(timeout \\ @export_timeout_ms) do
    GenServer.call(__MODULE__, :force_flush, timeout)
  catch
    :exit, {:noproc, _} -> {:error, :already_shutdown}
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  # --- GenServer ---

  @spec start_link(config :: config() | []) :: GenServer.on_start()
  def start_link(config \\ %{}) do
    GenServer.start_link(__MODULE__, normalize(config), name: __MODULE__)
  end

  @spec normalize(config :: config() | []) :: map()
  defp normalize([]), do: %{}
  defp normalize(map) when is_map(map), do: map

  @impl GenServer
  @spec init(config :: config()) :: {:ok, map()}
  def init(config) do
    # `Otel.Application` supervises this child with `[]` config —
    # exporter and resource come from the user's
    # `config :otel, exporter: %{...}` and `:resource` keys here.
    # Tests that want a custom exporter (e.g. FakeExporter) override
    # via the args.
    Process.flag(:trap_exit, true)

    exporter =
      Map.get(config, :exporter, {Otel.Trace.SpanExporter, exporter_app_env()})

    resource =
      Map.get_lazy(config, :resource, &Otel.Resource.from_app_env/0)

    state = %{
      exporter: init_exporter(exporter),
      resource: resource,
      queue: [],
      queue_size: 0
    }

    schedule_export()
    {:ok, state}
  end

  @spec exporter_app_env() :: map()
  defp exporter_app_env, do: Application.get_env(:otel, :exporter, %{})

  # Runs the exporter's own `init/1` so OTLP HTTP can populate
  # compression / SSL defaults; `:ignore` demotes to `nil`.
  @spec init_exporter({module(), term()} | nil) :: {module(), term()} | nil
  defp init_exporter(nil), do: nil

  defp init_exporter({module, opts}) do
    case module.init(opts) do
      {:ok, state} -> {module, state}
      :ignore -> nil
    end
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

  @impl GenServer
  @spec handle_info(msg :: term(), state :: map()) :: {:noreply, map()}
  def handle_info(:export_timer, state) do
    new_state = export_batch(state)
    schedule_export()
    {:noreply, new_state}
  end

  # Supervisor-driven termination (`Application.stop(:otel)` or any
  # `:shutdown` signal): drain the queue and call the exporter's
  # `shutdown/1` so spans pending at termination still leave the
  # process. `trap_exit: true` in `init/1` is what makes this run.
  #
  # The drain step calls `exporter.export/3`, which can fail (network
  # error, broken exporter state, etc.). We catch any such failure so
  # that `exporter.shutdown` always runs — `code-conventions.md`
  # exempts lifecycle hooks from the happy-path rule.
  @impl GenServer
  @spec terminate(reason :: term(), state :: map()) :: :ok
  def terminate(_reason, state) do
    new_state =
      try do
        export_batch(state)
      catch
        _kind, _reason -> %{state | queue: [], queue_size: 0}
      end

    case new_state.exporter do
      {module, exporter_state} -> module.shutdown(exporter_state)
      nil -> :ok
    end

    :ok
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
  # export trigger (timer, force_flush, terminate). The
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
