defmodule Otel.API.Metrics.UpDownCounter do
  @moduledoc """
  Synchronous UpDownCounter instrument.

  An UpDownCounter supports both increments and decrements. Created
  exclusively through a Meter.

  The value can be positive or negative. If values are monotonically
  increasing, use Counter instead.

  All functions are safe for concurrent use.
  """

  use Otel.API.Types

  @doc """
  Creates an UpDownCounter instrument via the given Meter.

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
    Otel.API.Metrics.Meter.create_updown_counter(meter, name, opts)
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
  Increments or decrements the UpDownCounter by the given value.

  The value can be positive or negative. Attributes are optional.

  Instrumentation authors should call `enabled?/2` before each call
  to avoid expensive computation when disabled.
  """
  @spec add(
          instrument :: Otel.API.Metrics.Instrument.t(),
          value :: number(),
          attributes :: %{String.t() => primitive() | [primitive()]}
        ) :: :ok
  def add(instrument, value, attributes \\ %{}) do
    Otel.API.Metrics.Meter.record(instrument, value, attributes)
  end
end
