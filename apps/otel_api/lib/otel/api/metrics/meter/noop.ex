defmodule Otel.API.Metrics.Meter.Noop do
  @moduledoc """
  No-op Meter implementation.

  Used when no SDK is installed. All instrument creation returns `:ok`,
  and `enabled?` returns `false`.

  All functions are safe for concurrent use.
  """

  @behaviour Otel.API.Metrics.Meter

  @impl true
  @spec create_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: term()
  def create_counter(_meter, _name, _opts), do: :ok

  @impl true
  @spec create_histogram(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: term()
  def create_histogram(_meter, _name, _opts), do: :ok

  @impl true
  @spec create_gauge(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: term()
  def create_gauge(_meter, _name, _opts), do: :ok

  @impl true
  @spec create_updown_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: term()
  def create_updown_counter(_meter, _name, _opts), do: :ok

  @impl true
  @spec create_observable_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: term()
  def create_observable_counter(_meter, _name, _opts), do: :ok

  @impl true
  @spec create_observable_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: keyword()
        ) :: term()
  def create_observable_counter(_meter, _name, _callback, _callback_args, _opts), do: :ok

  @impl true
  @spec create_observable_gauge(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: term()
  def create_observable_gauge(_meter, _name, _opts), do: :ok

  @impl true
  @spec create_observable_gauge(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: keyword()
        ) :: term()
  def create_observable_gauge(_meter, _name, _callback, _callback_args, _opts), do: :ok

  @impl true
  @spec create_observable_updown_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: keyword()
        ) :: term()
  def create_observable_updown_counter(_meter, _name, _opts), do: :ok

  @impl true
  @spec create_observable_updown_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: keyword()
        ) :: term()
  def create_observable_updown_counter(_meter, _name, _callback, _callback_args, _opts), do: :ok

  @impl true
  @spec record(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          value :: number(),
          attributes :: Otel.API.Attribute.attributes()
        ) :: :ok
  def record(_meter, _name, _value, _attributes), do: :ok

  @impl true
  @spec register_callback(
          meter :: Otel.API.Metrics.Meter.t(),
          instruments :: [term()],
          callback :: function(),
          callback_args :: term(),
          opts :: keyword()
        ) :: term()
  def register_callback(_meter, _instruments, _callback, _callback_args, _opts), do: :ok

  @impl true
  @spec enabled?(meter :: Otel.API.Metrics.Meter.t(), opts :: keyword()) :: boolean()
  def enabled?(_meter, _opts), do: false
end
