defmodule Otel.API.Metrics.Histogram do
  @moduledoc """
  Synchronous Histogram instrument.

  A Histogram reports arbitrary values that are likely to be
  statistically meaningful. Created exclusively through a Meter.

  The value is expected to be non-negative. The API does not
  validate the value; validation is deferred to the SDK.

  All functions are safe for concurrent use.
  """

  @doc """
  Creates a Histogram instrument via the given Meter.

  Options:
  - `:unit` — case-sensitive ASCII string (max 63 chars)
  - `:description` — opaque string (BMP, at least 1023 chars)
  - `:advisory` — advisory parameters (e.g. `explicit_bucket_boundaries`)
  """
  @spec create(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: term()
  def create(meter, name, opts \\ []) do
    Otel.API.Metrics.Meter.create_histogram(meter, name, opts)
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
  Records a value in the Histogram.

  The value is expected to be non-negative. Attributes are optional.

  Instrumentation authors should call `Otel.API.Metrics.Meter.enabled?/2`
  before each call to avoid expensive computation when disabled.
  """
  @spec record(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          value :: number(),
          attributes :: Otel.API.Attribute.attributes()
        ) :: :ok
  def record(meter, name, value, attributes \\ %{}) do
    Otel.API.Metrics.Meter.record(meter, name, value, attributes)
  end
end
