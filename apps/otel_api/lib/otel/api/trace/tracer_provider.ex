defmodule Otel.API.Trace.TracerProvider do
  @moduledoc """
  Global TracerProvider registration and Tracer retrieval.

  Uses `persistent_term` for storage, matching opentelemetry-erlang.
  When no SDK is installed, all operations return no-op tracers.

  All functions are safe for concurrent use.
  """

  @default_tracer {Otel.API.Trace.Tracer.Noop, []}

  @global_key {__MODULE__, :global}
  @tracer_key_prefix {__MODULE__, :tracer}

  @typedoc """
  A `{dispatcher_module, state}` pair.

  The API layer treats the state as opaque; only `dispatcher_module`
  knows how to use it. This mirrors `Otel.API.Trace.Tracer.t/0` and
  keeps the API decoupled from SDK internals (GenServer, Registry,
  etc.).

  `dispatcher_module` MUST implement the `Otel.API.Trace.TracerProvider`
  behaviour.
  """
  @type t :: {module(), term()}

  @doc """
  Returns a tracer for the given instrumentation scope.

  Called by the API layer when no cached tracer matches the scope.
  Implementations receive the opaque `state` they registered via
  `set_provider/1`.
  """
  @callback get_tracer(
              state :: term(),
              instrumentation_scope :: Otel.API.InstrumentationScope.t()
            ) :: Otel.API.Trace.Tracer.t()

  @doc """
  Returns the global TracerProvider, or `nil` if none is set.
  """
  @spec get_provider() :: t() | nil
  def get_provider do
    :persistent_term.get(@global_key, nil)
  end

  @doc """
  Sets the global TracerProvider.

  Accepts a `{module, state}` tuple. The SDK TracerProvider calls this
  from its `init/1` with `{__MODULE__, server_ref}`. `nil` clears the
  registration.
  """
  @spec set_provider(provider :: t() | nil) :: :ok
  def set_provider({module, _state} = provider) when is_atom(module) do
    :persistent_term.put(@global_key, provider)
    :ok
  end

  def set_provider(nil) do
    :persistent_term.put(@global_key, nil)
    :ok
  end

  @doc """
  Returns a Tracer for the given instrumentation scope.

  Accepts an `Otel.API.InstrumentationScope` struct. Without arguments,
  uses a default empty scope. Tracers are cached in `persistent_term`
  keyed by the scope value.
  """
  @spec get_tracer(instrumentation_scope :: Otel.API.InstrumentationScope.t()) ::
          Otel.API.Trace.Tracer.t()
  def get_tracer(instrumentation_scope \\ %Otel.API.InstrumentationScope{})

  def get_tracer(%Otel.API.InstrumentationScope{} = instrumentation_scope) do
    key = {@tracer_key_prefix, instrumentation_scope}

    case :persistent_term.get(key, nil) do
      nil ->
        tracer = fetch_or_default(instrumentation_scope)
        :persistent_term.put(key, tracer)
        tracer

      tracer ->
        tracer
    end
  end

  @spec fetch_or_default(instrumentation_scope :: Otel.API.InstrumentationScope.t()) ::
          Otel.API.Trace.Tracer.t()
  defp fetch_or_default(%Otel.API.InstrumentationScope{} = instrumentation_scope) do
    case get_provider() do
      nil ->
        @default_tracer

      {module, state} ->
        module.get_tracer(state, instrumentation_scope)
    end
  end
end
