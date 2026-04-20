defmodule Otel.API.Metrics.Meter.Noop do
  @moduledoc """
  No-op Meter implementation.

  Used when no SDK is installed. All instrument creation returns an
  `Otel.API.Metrics.Instrument` struct (with only identifying fields
  populated), and `enabled?` returns `false`.

  All functions are safe for concurrent use.
  """

  @behaviour Otel.API.Metrics.Meter

  @impl true
  @spec create_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_counter(meter, name, opts), do: build(meter, name, :counter, opts)

  @impl true
  @spec create_histogram(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_histogram(meter, name, opts), do: build(meter, name, :histogram, opts)

  @impl true
  @spec create_gauge(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_gauge(meter, name, opts), do: build(meter, name, :gauge, opts)

  @impl true
  @spec create_updown_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_updown_counter(meter, name, opts), do: build(meter, name, :updown_counter, opts)

  @impl true
  @spec create_observable_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_counter(meter, name, opts),
    do: build(meter, name, :observable_counter, opts)

  @impl true
  @spec create_observable_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_counter(meter, name, _callback, _callback_args, opts),
    do: build(meter, name, :observable_counter, opts)

  @impl true
  @spec create_observable_gauge(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_gauge(meter, name, opts),
    do: build(meter, name, :observable_gauge, opts)

  @impl true
  @spec create_observable_gauge(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_gauge(meter, name, _callback, _callback_args, opts),
    do: build(meter, name, :observable_gauge, opts)

  @impl true
  @spec create_observable_updown_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_updown_counter(meter, name, opts),
    do: build(meter, name, :observable_updown_counter, opts)

  @impl true
  @spec create_observable_updown_counter(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_updown_counter(meter, name, _callback, _callback_args, opts),
    do: build(meter, name, :observable_updown_counter, opts)

  @impl true
  @spec record(
          instrument :: Otel.API.Metrics.Instrument.t(),
          value :: number(),
          attributes :: %{Otel.API.Attribute.key() => Otel.API.Attribute.value()}
        ) :: :ok
  def record(_instrument, _value, _attributes), do: :ok

  @impl true
  @spec register_callback(
          meter :: Otel.API.Metrics.Meter.t(),
          instruments :: [Otel.API.Metrics.Instrument.t()],
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.register_callback_opts()
        ) :: Otel.API.Metrics.Meter.registration()
  def register_callback(_meter, _instruments, _callback, _callback_args, _opts),
    do: {__MODULE__, :noop}

  @impl true
  @spec unregister_callback(state :: term()) :: :ok
  def unregister_callback(_state), do: :ok

  @impl true
  @spec enabled?(
          instrument :: Otel.API.Metrics.Instrument.t(),
          opts :: Otel.API.Metrics.Instrument.enabled_opts()
        ) :: boolean()
  def enabled?(_instrument, _opts), do: false

  @spec build(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          kind :: Otel.API.Metrics.Instrument.kind(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  defp build(meter, name, kind, opts) do
    %Otel.API.Metrics.Instrument{
      meter: meter,
      name: name || "",
      kind: kind,
      unit: Keyword.get(opts, :unit, "") || "",
      description: Keyword.get(opts, :description, "") || "",
      advisory: Keyword.get(opts, :advisory, [])
    }
  end
end
