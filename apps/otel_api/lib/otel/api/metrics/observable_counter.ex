defmodule Otel.API.Metrics.ObservableCounter do
  @moduledoc """
  Asynchronous Counter instrument.

  Reports monotonically increasing absolute value(s) when the
  instrument is being observed. Created exclusively through a Meter.

  Unlike `Counter.add`, the callback reports the absolute value —
  the SDK derives rate of change by differencing successive readings.

  Callbacks should be reentrant safe, should not take indefinite time,
  and should not make duplicate observations (same attributes across
  all callbacks). These are documented expectations, not enforced.

  All functions are safe for concurrent use.
  """

  @doc """
  Creates an ObservableCounter without an inline callback.

  Register callbacks later via `Otel.API.Metrics.Meter.register_callback/5`.

  Options:
  - `:unit` — case-sensitive ASCII string (max 63 chars)
  - `:description` — opaque string (BMP, at least 1023 chars)
  - `:advisory` — advisory parameters
  """
  @spec create(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: Otel.API.Metrics.Instrument.t()
  def create(meter, name, opts \\ []) do
    Otel.API.Metrics.Meter.create_observable_counter(meter, name, opts)
  end

  @doc """
  Creates an ObservableCounter with an inline callback.

  The callback is permanently registered to this instrument. It receives
  `callback_args` and returns a list of `Otel.API.Metrics.Measurement.t()`.

  Options:
  - `:unit` — case-sensitive ASCII string (max 63 chars)
  - `:description` — opaque string (BMP, at least 1023 chars)
  - `:advisory` — advisory parameters
  """
  @spec create(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: (term() -> [Otel.API.Metrics.Measurement.t()]),
          callback_args :: term(),
          opts :: keyword()
        ) :: Otel.API.Metrics.Instrument.t()
  def create(meter, name, callback, callback_args, opts) do
    Otel.API.Metrics.Meter.create_observable_counter(meter, name, callback, callback_args, opts)
  end
end
