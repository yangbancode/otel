defmodule Otel.API.Metrics.Meter do
  @moduledoc """
  Meter behaviour and dispatch.

  A Meter is responsible for creating instruments. It is represented
  as a `{module, config}` tuple where the module implements this
  behaviour. Meter SHOULD NOT be responsible for configuration —
  that is the MeterProvider's responsibility.

  All functions are safe for concurrent use.
  """

  @type t :: {module(), term()}

  @typedoc """
  Handle returned by `register_callback/5`. Pass to
  `unregister_callback/1` to undo the registration.

  Carries the dispatcher module plus SDK-specific state; the API
  layer treats the state as opaque. Callers should not rely on the
  internal shape.
  """
  @type registration :: {module(), term()}

  # --- Synchronous Instruments ---

  @callback create_counter(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()
  @callback create_histogram(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()
  @callback create_gauge(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()
  @callback create_updown_counter(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  # --- Asynchronous Instruments ---

  @callback create_observable_counter(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()
  @callback create_observable_counter(
              meter :: t(),
              name :: String.t(),
              callback :: function(),
              callback_args :: term(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()
  @callback create_observable_gauge(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()
  @callback create_observable_gauge(
              meter :: t(),
              name :: String.t(),
              callback :: function(),
              callback_args :: term(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()
  @callback create_observable_updown_counter(
              meter :: t(),
              name :: String.t(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()
  @callback create_observable_updown_counter(
              meter :: t(),
              name :: String.t(),
              callback :: function(),
              callback_args :: term(),
              opts :: Otel.API.Metrics.Instrument.create_opts()
            ) :: Otel.API.Metrics.Instrument.t()

  # --- Callback Registration ---

  @callback register_callback(
              meter :: t(),
              instruments :: [Otel.API.Metrics.Instrument.t()],
              callback :: function(),
              callback_args :: term(),
              opts :: Otel.API.Metrics.Instrument.register_callback_opts()
            ) :: registration()

  @callback unregister_callback(state :: term()) :: :ok

  # --- Recording ---

  @callback record(
              instrument :: Otel.API.Metrics.Instrument.t(),
              value :: number(),
              attributes :: Otel.API.Attributes.t()
            ) :: :ok

  # --- Enabled ---

  @callback enabled?(
              instrument :: Otel.API.Metrics.Instrument.t(),
              opts :: Otel.API.Metrics.Instrument.enabled_opts()
            ) :: boolean()

  # --- Dispatch Functions ---

  @doc """
  Creates a Counter instrument.
  """
  @spec create_counter(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_counter({module, _} = meter, name, opts \\ []) do
    module.create_counter(meter, name, opts)
  end

  @doc """
  Creates a Histogram instrument.
  """
  @spec create_histogram(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_histogram({module, _} = meter, name, opts \\ []) do
    module.create_histogram(meter, name, opts)
  end

  @doc """
  Creates a synchronous Gauge instrument.
  """
  @spec create_gauge(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_gauge({module, _} = meter, name, opts \\ []) do
    module.create_gauge(meter, name, opts)
  end

  @doc """
  Creates an UpDownCounter instrument.
  """
  @spec create_updown_counter(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_updown_counter({module, _} = meter, name, opts \\ []) do
    module.create_updown_counter(meter, name, opts)
  end

  @doc """
  Creates an observable (asynchronous) Counter instrument.
  """
  @spec create_observable_counter(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_counter({module, _} = meter, name, opts \\ []) do
    module.create_observable_counter(meter, name, opts)
  end

  @doc """
  Creates an observable Counter with an inline callback.
  """
  @spec create_observable_counter(
          meter :: t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_counter({module, _} = meter, name, callback, callback_args, opts) do
    module.create_observable_counter(meter, name, callback, callback_args, opts)
  end

  @doc """
  Creates an observable (asynchronous) Gauge instrument.
  """
  @spec create_observable_gauge(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_gauge({module, _} = meter, name, opts \\ []) do
    module.create_observable_gauge(meter, name, opts)
  end

  @doc """
  Creates an observable Gauge with an inline callback.
  """
  @spec create_observable_gauge(
          meter :: t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_gauge({module, _} = meter, name, callback, callback_args, opts) do
    module.create_observable_gauge(meter, name, callback, callback_args, opts)
  end

  @doc """
  Creates an observable (asynchronous) UpDownCounter instrument.
  """
  @spec create_observable_updown_counter(
          meter :: t(),
          name :: String.t(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_updown_counter({module, _} = meter, name, opts \\ []) do
    module.create_observable_updown_counter(meter, name, opts)
  end

  @doc """
  Creates an observable UpDownCounter with an inline callback.
  """
  @spec create_observable_updown_counter(
          meter :: t(),
          name :: String.t(),
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  def create_observable_updown_counter({module, _} = meter, name, callback, callback_args, opts) do
    module.create_observable_updown_counter(meter, name, callback, callback_args, opts)
  end

  @doc """
  Records a measurement for the given instrument.

  All synchronous instrument recording operations (Counter.add,
  Histogram.record, Gauge.record, UpDownCounter.add) route through
  this function.
  """
  @spec record(
          instrument :: Otel.API.Metrics.Instrument.t(),
          value :: number(),
          attributes :: Otel.API.Attributes.t()
        ) :: :ok
  def record(
        %Otel.API.Metrics.Instrument{meter: {module, _}} = instrument,
        value,
        attributes \\ %{}
      ) do
    module.record(instrument, value, attributes)
  end

  @doc """
  Registers a callback for one or more asynchronous instruments.

  The callback will be invoked during metric collection. All instruments
  must belong to the same Meter.
  """
  @spec register_callback(
          meter :: t(),
          instruments :: [Otel.API.Metrics.Instrument.t()],
          callback :: function(),
          callback_args :: term(),
          opts :: Otel.API.Metrics.Instrument.register_callback_opts()
        ) :: registration()
  def register_callback({module, _} = meter, instruments, callback, callback_args, opts \\ []) do
    module.register_callback(meter, instruments, callback, callback_args, opts)
  end

  @doc """
  Undoes a prior `register_callback/5` registration.

  `registration` is the opaque handle returned by `register_callback/5`.
  After this call, the callback is no longer evaluated during collection.
  """
  @spec unregister_callback(registration :: registration()) :: :ok
  def unregister_callback({module, state}) do
    module.unregister_callback(state)
  end

  @doc """
  Returns whether the given instrument is enabled.
  """
  @spec enabled?(
          instrument :: Otel.API.Metrics.Instrument.t(),
          opts :: Otel.API.Metrics.Instrument.enabled_opts()
        ) :: boolean()
  def enabled?(%Otel.API.Metrics.Instrument{meter: {module, _}} = instrument, opts \\ []) do
    module.enabled?(instrument, opts)
  end
end
