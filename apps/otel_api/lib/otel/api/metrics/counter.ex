defmodule Otel.API.Metrics.Counter do
  @moduledoc """
  Synchronous Counter instrument.

  A Counter supports non-negative increments. Created exclusively
  through a Meter — there is no other API for creating a Counter.

  The increment value is expected to be non-negative. The API does
  not validate the value; validation is deferred to the SDK.

  All functions are safe for concurrent use.
  """

  @doc """
  Creates a Counter instrument via the given Meter.

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
    Otel.API.Metrics.Meter.create_counter(meter, name, opts)
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
  Increments the Counter by the given value.

  The value is expected to be non-negative. Attributes are optional.

  Instrumentation authors should call `Otel.API.Metrics.Meter.enabled?/2`
  before each call to avoid expensive computation when disabled.
  """
  @spec add(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          value :: number(),
          attributes :: [Otel.API.Common.Attribute.t()]
        ) :: :ok
  def add(meter, name, value, attributes \\ []) do
    Otel.API.Metrics.Meter.record(meter, name, value, attributes)
  end
end
