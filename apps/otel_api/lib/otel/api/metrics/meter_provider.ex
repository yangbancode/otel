defmodule Otel.API.Metrics.MeterProvider do
  @moduledoc """
  Global MeterProvider registration and Meter retrieval.

  Uses `persistent_term` for storage, matching opentelemetry-erlang.
  When no SDK is installed, all operations return no-op meters.

  All functions are safe for concurrent use.
  """

  @default_meter {Otel.API.Metrics.Meter.Noop, []}

  @global_key {__MODULE__, :global}
  @meter_key_prefix {__MODULE__, :meter}

  @typedoc """
  A `{dispatcher_module, state}` pair.

  The API layer treats the state as opaque; only `dispatcher_module`
  knows how to use it. This mirrors `Otel.API.Metrics.Meter.t/0` and
  keeps the API decoupled from SDK internals.

  `dispatcher_module` MUST implement the `Otel.API.Metrics.MeterProvider`
  behaviour.
  """
  @type t :: {module(), term()}

  @doc """
  Returns a meter for the given instrumentation scope.

  Called by the API layer when no cached meter matches the scope.
  Implementations receive the opaque `state` they registered via
  `set_provider/1`.
  """
  @callback get_meter(
              state :: term(),
              name :: String.t(),
              version :: String.t(),
              schema_url :: String.t() | nil,
              attributes :: Otel.API.Attribute.attributes()
            ) :: Otel.API.Metrics.Meter.t()

  @doc """
  Returns the global MeterProvider, or `nil` if none is set.
  """
  @spec get_provider() :: t() | nil
  def get_provider do
    :persistent_term.get(@global_key, nil)
  end

  @doc """
  Sets the global MeterProvider.

  Accepts a `{module, state}` tuple. The SDK MeterProvider calls this
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
  Returns a Meter for the given instrumentation scope.

  Invalid name (nil or empty) returns a working Meter with empty
  name. Meters are cached in `persistent_term`.
  """
  @spec get_meter(
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: Otel.API.Attribute.attributes()
        ) :: Otel.API.Metrics.Meter.t()
  def get_meter(name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    key = {@meter_key_prefix, {name, version, schema_url, attributes}}

    case :persistent_term.get(key, nil) do
      nil ->
        meter = fetch_or_default(name, version, schema_url, attributes)
        :persistent_term.put(key, meter)
        meter

      meter ->
        meter
    end
  end

  @doc """
  Returns the InstrumentationScope for a meter obtained with the
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

  @spec fetch_or_default(
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: Otel.API.Attribute.attributes()
        ) :: Otel.API.Metrics.Meter.t()
  defp fetch_or_default(name, version, schema_url, attributes) do
    case get_provider() do
      nil ->
        @default_meter

      {module, state} ->
        module.get_meter(state, name, version, schema_url, attributes)
    end
  end
end
