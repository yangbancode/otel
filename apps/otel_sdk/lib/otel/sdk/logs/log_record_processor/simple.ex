defmodule Otel.SDK.Logs.LogRecordProcessor.Simple do
  @moduledoc """
  SimpleLogRecordProcessor that exports each log record immediately.

  Uses a GenServer to serialize export calls — the exporter is
  never called concurrently (L521).
  """

  use GenServer

  @behaviour Otel.SDK.Logs.LogRecordProcessor

  # --- LogRecordProcessor callbacks ---

  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec on_emit(log_record :: map(), config :: Otel.SDK.Logs.LogRecordProcessor.config()) :: :ok
  def on_emit(log_record, %{reg_name: reg_name}) do
    GenServer.call(reg_name, {:export, log_record})
  end

  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec enabled?(opts :: keyword(), config :: Otel.SDK.Logs.LogRecordProcessor.config()) ::
          boolean()
  def enabled?(_opts, _config), do: true

  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec shutdown(config :: Otel.SDK.Logs.LogRecordProcessor.config()) :: :ok | {:error, term()}
  def shutdown(%{reg_name: reg_name}) do
    GenServer.call(reg_name, :shutdown)
  end

  @impl Otel.SDK.Logs.LogRecordProcessor
  @spec force_flush(config :: Otel.SDK.Logs.LogRecordProcessor.config()) :: :ok | {:error, term()}
  def force_flush(_config), do: :ok

  # --- GenServer ---

  @spec start_link(config :: map()) :: GenServer.on_start()
  def start_link(config) do
    name = Map.get(config, :name, __MODULE__)
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @impl GenServer
  @spec init(config :: map()) :: {:ok, map()}
  def init(config) do
    {exporter_module, exporter_opts} = Map.fetch!(config, :exporter)

    case exporter_module.init(exporter_opts) do
      {:ok, exporter_state} ->
        {:ok,
         %{
           exporter: {exporter_module, exporter_state},
           name: Map.get(config, :name, __MODULE__),
           shut_down: false
         }}

      :ignore ->
        {:ok, %{exporter: nil, name: Map.get(config, :name, __MODULE__), shut_down: false}}
    end
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
    module.shutdown(exporter_state)
    {:reply, :ok, %{state | exporter: nil, shut_down: true}}
  end
end
