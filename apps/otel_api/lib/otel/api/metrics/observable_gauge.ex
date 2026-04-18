defmodule Otel.API.Metrics.ObservableGauge do
  @moduledoc """
  Asynchronous Gauge instrument.

  Reports non-additive value(s) when the instrument is being observed.
  Created exclusively through a Meter.

  Use this when values are fetched via an accessor (e.g. reading a
  sensor). If values arrive via change-event subscriptions, use the
  synchronous `Gauge` instead.

  Callbacks should be reentrant safe, should not take indefinite time,
  and should not make duplicate observations (same attributes across
  all callbacks). These are documented expectations, not enforced.

  All functions are safe for concurrent use.
  """

  @doc """
  Creates an ObservableGauge without an inline callback.

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
        ) :: term()
  def create(meter, name, opts \\ []) do
    Otel.API.Metrics.Meter.create_observable_gauge(meter, name, opts)
  end

  @doc """
  Creates an ObservableGauge with an inline callback.

  The callback is permanently registered to this instrument. It receives
  `callback_args` and returns a list of `{value, attributes}` observations.

  Options:
  - `:unit` — case-sensitive ASCII string (max 63 chars)
  - `:description` — opaque string (BMP, at least 1023 chars)
  - `:advisory` — advisory parameters
  """
  @spec create(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: (term() -> [{number(), Otel.API.Attribute.attributes()}]),
          callback_args :: term(),
          opts :: keyword()
        ) :: term()
  def create(meter, name, callback, callback_args, opts) do
    Otel.API.Metrics.Meter.create_observable_gauge(meter, name, callback, callback_args, opts)
  end
end
