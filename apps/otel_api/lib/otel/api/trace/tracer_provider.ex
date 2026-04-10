defmodule Otel.API.Trace.TracerProvider do
  @moduledoc """
  Global TracerProvider registration and Tracer retrieval.

  Uses `persistent_term` for storage, matching opentelemetry-erlang.
  When no SDK is installed, all operations return no-op tracers.
  """

  alias Otel.API.Trace.{InstrumentationScope, Noop, Tracer}

  @default_tracer {Noop, []}

  @provider_key {__MODULE__, :global}
  @tracer_key_prefix {__MODULE__, :tracer}

  @doc """
  Returns the global TracerProvider module, or `nil` if none is set.
  """
  @spec get_provider() :: module() | nil
  def get_provider do
    :persistent_term.get(@provider_key, nil)
  end

  @doc """
  Sets the global TracerProvider module.
  """
  @spec set_provider(module()) :: :ok
  def set_provider(provider) when is_atom(provider) do
    :persistent_term.put(@provider_key, provider)
    :ok
  end

  @doc """
  Returns a Tracer for the given instrumentation scope.

  Invalid name (nil or empty) returns a working Tracer with empty
  name and logs a warning. Tracers are cached in `persistent_term`.
  """
  @spec get_tracer(String.t(), String.t(), String.t() | nil) :: Tracer.t()
  def get_tracer(name, version \\ "", schema_url \\ nil) do
    name = validate_name(name)
    key = {@tracer_key_prefix, {name, version, schema_url}}

    case :persistent_term.get(key, nil) do
      nil ->
        tracer = fetch_or_default(name, version, schema_url)
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
  @spec scope(String.t(), String.t(), String.t() | nil) :: InstrumentationScope.t()
  def scope(name, version \\ "", schema_url \\ nil) do
    %InstrumentationScope{name: name, version: version, schema_url: schema_url}
  end

  defp validate_name(nil) do
    :logger.warning("TracerProvider: invalid tracer name nil, using empty string",
      %{domain: [:otel]}
    )

    ""
  end

  defp validate_name("") do
    :logger.warning("TracerProvider: invalid tracer name (empty string)",
      %{domain: [:otel]}
    )

    ""
  end

  defp validate_name(name) when is_binary(name), do: name

  defp fetch_or_default(_name, _version, _schema_url) do
    @default_tracer
  end
end
