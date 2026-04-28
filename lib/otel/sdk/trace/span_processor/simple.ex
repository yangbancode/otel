defmodule Otel.SDK.Trace.SpanProcessor.Simple do
  @moduledoc """
  SimpleSpanProcessor that exports each span immediately on
  end (`trace/sdk.md` §Simple processor L1076-L1084).

  Uses a GenServer to serialize export calls — the exporter
  is never called concurrently (spec L1146-L1147).

  ## Public API

  | Function | Role |
  |---|---|
  | `start_link/1` | **SDK** (lifecycle) |
  | `on_start/3`, `on_end/2`, `shutdown/2`, `force_flush/2` | **SDK** (Simple implementation) |

  ## References

  - OTel Trace SDK §Simple processor: `opentelemetry-specification/specification/trace/sdk.md` L1076-L1084
  - Parent behaviour: `Otel.SDK.Trace.SpanProcessor`
  """

  use GenServer

  @behaviour Otel.SDK.Trace.SpanProcessor

  # --- SpanProcessor callbacks ---

  @spec on_start(
          ctx :: Otel.API.Ctx.t(),
          span :: Otel.SDK.Trace.Span.t(),
          config :: Otel.SDK.Trace.SpanProcessor.config()
        ) :: Otel.SDK.Trace.Span.t()
  @impl Otel.SDK.Trace.SpanProcessor
  def on_start(_ctx, span, _config), do: span

  @default_timeout_ms 30_000

  @spec on_end(
          span :: Otel.SDK.Trace.Span.t(),
          config :: Otel.SDK.Trace.SpanProcessor.config()
        ) :: :ok | :dropped | {:error, term()}
  @impl Otel.SDK.Trace.SpanProcessor
  def on_end(span, %{pid: pid}) do
    if Bitwise.band(span.trace_flags, 1) != 0 do
      GenServer.call(pid, {:export, span})
    else
      :dropped
    end
  end

  @spec shutdown(config :: Otel.SDK.Trace.SpanProcessor.config(), timeout :: timeout()) ::
          :ok | {:error, term()}
  @impl Otel.SDK.Trace.SpanProcessor
  def shutdown(%{pid: pid}, timeout \\ @default_timeout_ms) do
    GenServer.call(pid, :shutdown, timeout)
  catch
    :exit, {:noproc, _} -> {:error, :already_shutdown}
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  @spec force_flush(config :: Otel.SDK.Trace.SpanProcessor.config(), timeout :: timeout()) ::
          :ok | {:error, term()}
  @impl Otel.SDK.Trace.SpanProcessor
  def force_flush(_config, _timeout \\ @default_timeout_ms), do: :ok

  # --- GenServer ---

  @spec start_link(config :: Otel.SDK.Trace.SpanProcessor.config()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @impl GenServer
  @spec init(config :: Otel.SDK.Trace.SpanProcessor.config()) :: {:ok, map()}
  def init(config) do
    {:ok,
     %{
       exporter: Otel.SDK.Exporter.Init.call(Map.fetch!(config, :exporter)),
       resource: Map.get(config, :resource, %{})
     }}
  end

  @impl GenServer
  @spec handle_call(msg :: term(), from :: GenServer.from(), state :: map()) ::
          {:reply, term(), map()}
  def handle_call({:export, _span}, _from, %{exporter: nil} = state) do
    {:reply, :dropped, state}
  end

  def handle_call(
        {:export, span},
        _from,
        %{exporter: {module, exporter_state}, resource: resource} = state
      ) do
    result = module.export([span], resource, exporter_state)
    {:reply, result, state}
  end

  def handle_call(:shutdown, _from, %{exporter: nil} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:shutdown, _from, %{exporter: {module, exporter_state}} = state) do
    module.shutdown(exporter_state)
    {:reply, :ok, %{state | exporter: nil}}
  end
end
