defmodule Otel.SDK.Trace.SpanProcessor.Simple do
  @moduledoc """
  SimpleSpanProcessor that exports each span immediately on end.

  Uses a GenServer to serialize export calls — the exporter is
  never called concurrently (L1076).
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

  @spec on_end(
          span :: Otel.SDK.Trace.Span.t(),
          config :: Otel.SDK.Trace.SpanProcessor.config()
        ) :: :ok | :dropped | {:error, term()}
  @impl Otel.SDK.Trace.SpanProcessor
  def on_end(span, %{reg_name: reg_name}) do
    if Bitwise.band(span.trace_flags, 1) != 0 do
      GenServer.call(reg_name, {:export, span})
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
  def force_flush(_config), do: :ok

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

    case exporter_module.init(exporter_opts) do
      {:ok, exporter_state} ->
        {:ok,
         %{
           exporter: {exporter_module, exporter_state},
           resource: Map.get(config, :resource, %{}),
           name: Map.get(config, :name, __MODULE__)
         }}

      :ignore ->
        {:ok, %{exporter: nil, resource: %{}, name: Map.get(config, :name, __MODULE__)}}
    end
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
