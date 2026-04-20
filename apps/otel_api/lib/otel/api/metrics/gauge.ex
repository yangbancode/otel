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

  use Otel.API.Types

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
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create(meter, name, opts \\ []) do
    Otel.API.Metrics.Meter.create_gauge(meter, name, opts)
  end

  @doc """
  Returns whether the instrument is enabled.

  Instrumentation authors should call this before each recording
  to avoid expensive computation when disabled. The return value
  can change over time.
  """
  @spec enabled?(
          instrument :: Otel.API.Metrics.Instrument.t(),
          opts :: Otel.API.Metrics.Instrument.enabled_opts()
        ) :: boolean()
  def enabled?(instrument, opts \\ []) do
    Otel.API.Metrics.Meter.enabled?(instrument, opts)
  end

  @doc """
  Records the current absolute value of the Gauge.

  Attributes are optional.

  Instrumentation authors should call `enabled?/2` before each call
  to avoid expensive computation when disabled.
  """
  @spec record(
          instrument :: Otel.API.Metrics.Instrument.t(),
          value :: number(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) :: :ok
  def record(instrument, value, attributes \\ %{}) do
    Otel.API.Metrics.Meter.record(instrument, value, attributes)
  end
end
