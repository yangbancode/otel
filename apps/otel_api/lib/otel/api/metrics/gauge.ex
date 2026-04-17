defmodule Otel.API.Metrics.Gauge do
  @moduledoc """
  Synchronous Gauge instrument.

  A Gauge records non-additive values when changes occur. Created
  exclusively through a Meter.

  Use this when values are received via change-event subscriptions.
  If values are fetched via an accessor, use an asynchronous Gauge
  with a callback instead.

  All functions are safe for concurrent use.
  """

  @doc """
  Creates a Gauge instrument via the given Meter.

  Options:
  - `:unit` — case-sensitive ASCII string (max 63 chars)
  - `:description` — opaque string (BMP, at least 1023 chars)
  - `:advisory` — advisory parameters (e.g. for SDK hints)
  """
  @spec create(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: term()
  def create(meter, name, opts \\ []) do
    Otel.API.Metrics.Meter.create_gauge(meter, name, opts)
  end

  @doc """
  Returns whether the meter backing this instrument is enabled.

  Instrumentation authors should call this before each recording
  to avoid expensive computation when disabled. The return value
  can change over time.
  """
  @spec enabled?(meter :: Otel.API.Metrics.Meter.t(), opts :: keyword()) :: boolean()
  def enabled?(meter, opts \\ []) do
    Otel.API.Metrics.Meter.enabled?(meter, opts)
  end

  @doc """
  Records the current absolute value of the Gauge.

  Attributes are optional.

  Instrumentation authors should call `Otel.API.Metrics.Meter.enabled?/2`
  before each call to avoid expensive computation when disabled.
  """
  @spec record(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          value :: number(),
          attributes :: [Otel.API.Common.Attribute.t()]
        ) :: :ok
  def record(meter, name, value, attributes \\ []) do
    Otel.API.Metrics.Meter.record(meter, name, value, attributes)
  end
end
