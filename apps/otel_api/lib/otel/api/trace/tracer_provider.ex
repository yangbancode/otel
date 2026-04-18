defmodule Otel.API.Trace.TracerProvider do
  @moduledoc """
  Global TracerProvider registration and Tracer retrieval.

  Uses `persistent_term` for storage, matching opentelemetry-erlang.
  When no SDK is installed, all operations return no-op tracers.
  """

  @default_tracer {Otel.API.Trace.Tracer.Noop, []}

  @provider_key {__MODULE__, :global}
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
              name :: String.t(),
              version :: String.t(),
              schema_url :: String.t() | nil,
              attributes :: Otel.API.Attribute.attributes()
            ) :: Otel.API.Trace.Tracer.t()

  @doc """
  Returns the global TracerProvider, or `nil` if none is set.
  """
  @spec get_provider() :: t() | nil
  def get_provider do
    :persistent_term.get(@provider_key, nil)
  end

  @doc """
  Sets the global TracerProvider.

  Accepts a `{module, state}` tuple. The SDK TracerProvider calls this
  from its `init/1` with `{__MODULE__, server_ref}`. `nil` clears the
  registration.
  """
  @spec set_provider(provider :: t() | nil) :: :ok
  def set_provider({module, _state} = provider) when is_atom(module) do
    :persistent_term.put(@provider_key, provider)
    :ok
  end

  def set_provider(nil) do
    :persistent_term.put(@provider_key, nil)
    :ok
  end

  @doc """
  Returns a Tracer for the given instrumentation scope.

  Invalid name (nil or empty) returns a working Tracer with empty
  name and logs a warning. Tracers are cached in `persistent_term`.
  """
  @spec get_tracer(
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: Otel.API.Attribute.attributes()
        ) :: Otel.API.Trace.Tracer.t()
  def get_tracer(name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    name = validate_name(name)
    key = {@tracer_key_prefix, {name, version, schema_url, attributes}}

    case :persistent_term.get(key, nil) do
      nil ->
        tracer = fetch_or_default(name, version, schema_url, attributes)
        :persistent_term.put(key, tracer)
        tracer

      tracer ->
        tracer
    end
  end

  @doc """
  Returns the InstrumentationScope for a tracer obtained with the
  given parameters.
  """
  @spec scope(
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: Otel.API.Attribute.attributes()
        ) ::
          Otel.API.InstrumentationScope.t()
  def scope(name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    %Otel.API.InstrumentationScope{
      name: name,
      version: version,
      schema_url: schema_url,
      attributes: attributes
    }
  end

  @spec validate_name(name :: String.t() | nil) :: String.t()
  defp validate_name(nil) do
    :logger.warning(
      "TracerProvider: invalid tracer name nil, using empty string",
      %{domain: [:otel, :trace]}
    )

    ""
  end

  defp validate_name("") do
    :logger.warning(
      "TracerProvider: invalid tracer name (empty string)",
      %{domain: [:otel, :trace]}
    )

    ""
  end

  defp validate_name(name) when is_binary(name), do: name

  @spec fetch_or_default(
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: Otel.API.Attribute.attributes()
        ) :: Otel.API.Trace.Tracer.t()
  defp fetch_or_default(name, version, schema_url, attributes) do
    case get_provider() do
      nil ->
        @default_tracer

      {module, state} ->
        module.get_tracer(state, name, version, schema_url, attributes)
    end
  end
end
