defmodule Otel.API.Metrics.MeterProvider do
  @moduledoc """
  Global MeterProvider registration and Meter retrieval.

  Uses `persistent_term` for storage, matching opentelemetry-erlang.
  When no SDK is installed, all operations return no-op meters.

  All functions are safe for concurrent use.
  """

  @default_meter {Otel.API.Metrics.Meter.Noop, []}

  @provider_key {__MODULE__, :global}
  @meter_key_prefix {__MODULE__, :meter}

  @doc """
  Returns the global MeterProvider module, or `nil` if none is set.
  """
  @spec get_provider() :: module() | nil
  def get_provider do
    :persistent_term.get(@provider_key, nil)
  end

  @doc """
  Sets the global MeterProvider module.
  """
  @spec set_provider(provider :: module()) :: :ok
  def set_provider(provider) when is_atom(provider) do
    :persistent_term.put(@provider_key, provider)
    :ok
  end

  @doc """
  Returns a Meter for the given instrumentation scope.

  Invalid name (nil or empty) returns a working Meter with empty
  name and logs a warning. Meters are cached in `persistent_term`.
  """
  @spec get_meter(
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: map()
        ) :: Otel.API.Metrics.Meter.t()
  def get_meter(name, version \\ "", schema_url \\ nil, attributes \\ %{}) do
    name = validate_name(name)
    key = {@meter_key_prefix, {name, version, schema_url}}

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
          attributes :: map()
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
      "MeterProvider: invalid meter name nil, using empty string",
      %{domain: [:otel, :metrics]}
    )

    ""
  end

  defp validate_name("") do
    :logger.warning(
      "MeterProvider: invalid meter name (empty string)",
      %{domain: [:otel, :metrics]}
    )

    ""
  end

  defp validate_name(name) when is_binary(name), do: name

  @spec fetch_or_default(
          name :: String.t(),
          version :: String.t(),
          schema_url :: String.t() | nil,
          attributes :: map()
        ) :: Otel.API.Metrics.Meter.t()
  defp fetch_or_default(_name, _version, _schema_url, _attributes) do
    @default_meter
  end
end
