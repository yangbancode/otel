defmodule Otel.SDK.Trace.TracerProvider do
  @moduledoc """
  SDK implementation of the TracerProvider.

  A `GenServer` that owns trace configuration (sampler, processors,
  id_generator, resource, span_limits) and creates tracers. Registers
  itself as the global TracerProvider on start.
  """

  use GenServer

  @type config :: %{
          sampler: {module(), term()},
          processors: [{module(), map()}],
          id_generator: module(),
          resource: Otel.SDK.Resource.t(),
          span_limits: Otel.SDK.Trace.SpanLimits.t()
        }

  # --- Client API ---

  @doc """
  Starts the TracerProvider with the given configuration.
  """
  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {config, server_opts} = Keyword.pop(opts, :config, %{})
    GenServer.start_link(__MODULE__, config, server_opts)
  end

  @doc """
  Returns a tracer for the given instrumentation scope.

  Falls back to the Noop tracer if `server` is no longer alive.
  """
  @spec get_tracer(
          server :: GenServer.server(),
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: Otel.API.Attribute.attributes()
        ) ::
          Otel.API.Trace.Tracer.t()
  def get_tracer(server, name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    if alive?(server) do
      GenServer.call(server, {:get_tracer, name, version, schema_url, attributes})
    else
      {Otel.API.Trace.Tracer.Noop, []}
    end
  end

  @spec alive?(server :: GenServer.server()) :: boolean()
  defp alive?(pid) when is_pid(pid), do: Process.alive?(pid)
  defp alive?(name) when is_atom(name), do: Process.whereis(name) != nil

  @doc """
  Returns the resource associated with this provider.
  """
  @spec resource(server :: GenServer.server()) :: Otel.SDK.Resource.t()
  def resource(server) do
    GenServer.call(server, :resource)
  end

  @doc """
  Returns the current configuration.
  """
  @spec config(server :: GenServer.server()) :: config()
  def config(server) do
    GenServer.call(server, :config)
  end

  @doc """
  Shuts down the TracerProvider.

  Invokes shutdown on all registered processors. After shutdown,
  get_tracer returns the noop tracer. Can only be called once.
  """
  @spec shutdown(server :: GenServer.server(), timeout :: timeout()) :: :ok | {:error, term()}
  def shutdown(server, timeout \\ 5000) do
    GenServer.call(server, :shutdown, timeout)
  end

  @doc """
  Forces all registered processors to export pending spans.
  """
  @spec force_flush(server :: GenServer.server(), timeout :: timeout()) :: :ok | {:error, term()}
  def force_flush(server, timeout \\ 5000) do
    GenServer.call(server, :force_flush, timeout)
  end

  # --- Server Callbacks ---

  @impl true
  def init(user_config) do
    config =
      Otel.SDK.Configuration.default_config()
      |> Map.merge(user_config)
      |> Map.put(:shut_down, false)

    Otel.API.Trace.TracerProvider.set_provider({__MODULE__, self_ref()})
    {:ok, config}
  end

  @spec self_ref() :: atom() | pid()
  defp self_ref do
    case Process.info(self(), :registered_name) do
      {:registered_name, name} when is_atom(name) -> name
      _ -> self()
    end
  end

  @impl true
  def handle_call(
        {:get_tracer, _name, _version, _schema_url, _attributes},
        _from,
        %{shut_down: true} = config
      ) do
    {:reply, {Otel.API.Trace.Tracer.Noop, []}, config}
  end

  def handle_call({:get_tracer, name, version, schema_url, attributes}, _from, config) do
    scope = %Otel.API.InstrumentationScope{
      name: name,
      version: version,
      schema_url: schema_url,
      attributes: attributes
    }

    sampler = Otel.SDK.Trace.Sampler.new(config.sampler)

    tracer_config = %{
      sampler: sampler,
      id_generator: config.id_generator,
      span_limits: config.span_limits,
      processors: config.processors,
      scope: scope
    }

    tracer = {Otel.SDK.Trace.Tracer, tracer_config}
    {:reply, tracer, config}
  end

  def handle_call(:shutdown, _from, %{shut_down: true} = config) do
    {:reply, {:error, :already_shut_down}, config}
  end

  def handle_call(:shutdown, _from, config) do
    result = invoke_all_processors(config.processors, :shutdown)
    {:reply, result, %{config | shut_down: true}}
  end

  def handle_call(:force_flush, _from, %{shut_down: true} = config) do
    {:reply, {:error, :shut_down}, config}
  end

  def handle_call(:force_flush, _from, config) do
    result = invoke_all_processors(config.processors, :force_flush)
    {:reply, result, config}
  end

  def handle_call(:resource, _from, config) do
    {:reply, config.resource, config}
  end

  def handle_call(:config, _from, config) do
    {:reply, config, config}
  end

  @spec invoke_all_processors(
          processors :: [{module(), map()}],
          function :: :shutdown | :force_flush
        ) :: :ok | {:error, [{module(), term()}]}
  defp invoke_all_processors(processors, function) do
    results =
      Enum.reduce(processors, [], fn {processor, processor_config}, errors ->
        case apply(processor, function, [processor_config]) do
          :ok -> errors
          {:error, reason} -> [{processor, reason} | errors]
        end
      end)

    case results do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end
end
