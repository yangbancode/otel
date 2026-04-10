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
          resource: map(),
          span_limits: map()
        }

  @default_config %{
    sampler: {Otel.SDK.Trace.Sampler.AlwaysOn, []},
    processors: [],
    id_generator: Otel.SDK.Trace.IdGenerator.Default,
    resource: %{},
    span_limits: %{
      attribute_count_limit: 128,
      event_count_limit: 128,
      link_count_limit: 128,
      attribute_per_event_count_limit: 128,
      attribute_per_link_count_limit: 128
    }
  }

  # --- Client API ---

  @doc """
  Starts the TracerProvider with the given configuration.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {config, server_opts} = Keyword.pop(opts, :config, %{})
    GenServer.start_link(__MODULE__, config, server_opts)
  end

  @doc """
  Returns a tracer for the given instrumentation scope.
  """
  @spec get_tracer(GenServer.server(), String.t(), String.t(), String.t() | nil) ::
          Otel.API.Trace.Tracer.t()
  def get_tracer(server, name, version \\ "", schema_url \\ nil) do
    GenServer.call(server, {:get_tracer, name, version, schema_url})
  end

  @doc """
  Returns the resource associated with this provider.
  """
  @spec resource(GenServer.server()) :: map()
  def resource(server) do
    GenServer.call(server, :resource)
  end

  @doc """
  Returns the current configuration.
  """
  @spec config(GenServer.server()) :: config()
  def config(server) do
    GenServer.call(server, :config)
  end

  # --- Server Callbacks ---

  @impl true
  def init(user_config) do
    config = Map.merge(@default_config, user_config)
    Otel.API.Trace.TracerProvider.set_provider(__MODULE__)
    {:ok, config}
  end

  @impl true
  def handle_call({:get_tracer, name, version, schema_url}, _from, config) do
    scope = %Otel.API.Trace.InstrumentationScope{
      name: name,
      version: version,
      schema_url: schema_url
    }

    tracer = {Otel.SDK.Trace.Tracer, %{provider: self(), scope: scope}}
    {:reply, tracer, config}
  end

  def handle_call(:resource, _from, config) do
    {:reply, config.resource, config}
  end

  def handle_call(:config, _from, config) do
    {:reply, config, config}
  end
end
