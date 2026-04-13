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

  # --- Synchronous Instruments ---

  @callback create_counter(meter :: t(), name :: String.t(), opts :: keyword()) :: term()
  @callback create_histogram(meter :: t(), name :: String.t(), opts :: keyword()) :: term()
  @callback create_gauge(meter :: t(), name :: String.t(), opts :: keyword()) :: term()
  @callback create_updown_counter(meter :: t(), name :: String.t(), opts :: keyword()) :: term()

  # --- Asynchronous Instruments ---

  @callback create_observable_counter(meter :: t(), name :: String.t(), opts :: keyword()) ::
              term()
  @callback create_observable_gauge(meter :: t(), name :: String.t(), opts :: keyword()) :: term()
  @callback create_observable_updown_counter(meter :: t(), name :: String.t(), opts :: keyword()) ::
              term()

  # --- Callback Registration ---

  @callback register_callback(
              meter :: t(),
              instruments :: [term()],
              callback :: function(),
              callback_args :: term(),
              opts :: keyword()
            ) :: :ok

  # --- Recording ---

  @callback record(
              meter :: t(),
              name :: String.t(),
              value :: number(),
              attributes :: map()
            ) :: :ok

  # --- Enabled ---

  @callback enabled?(meter :: t(), opts :: keyword()) :: boolean()

  # --- Dispatch Functions ---

  @doc """
  Creates a Counter instrument.
  """
  @spec create_counter(meter :: t(), name :: String.t(), opts :: keyword()) :: term()
  def create_counter({module, _} = meter, name, opts \\ []) do
    module.create_counter(meter, name, opts)
  end

  @doc """
  Creates a Histogram instrument.
  """
  @spec create_histogram(meter :: t(), name :: String.t(), opts :: keyword()) :: term()
  def create_histogram({module, _} = meter, name, opts \\ []) do
    module.create_histogram(meter, name, opts)
  end

  @doc """
  Creates a synchronous Gauge instrument.
  """
  @spec create_gauge(meter :: t(), name :: String.t(), opts :: keyword()) :: term()
  def create_gauge({module, _} = meter, name, opts \\ []) do
    module.create_gauge(meter, name, opts)
  end

  @doc """
  Creates an UpDownCounter instrument.
  """
  @spec create_updown_counter(meter :: t(), name :: String.t(), opts :: keyword()) :: term()
  def create_updown_counter({module, _} = meter, name, opts \\ []) do
    module.create_updown_counter(meter, name, opts)
  end

  @doc """
  Creates an observable (asynchronous) Counter instrument.
  """
  @spec create_observable_counter(meter :: t(), name :: String.t(), opts :: keyword()) :: term()
  def create_observable_counter({module, _} = meter, name, opts \\ []) do
    module.create_observable_counter(meter, name, opts)
  end

  @doc """
  Creates an observable (asynchronous) Gauge instrument.
  """
  @spec create_observable_gauge(meter :: t(), name :: String.t(), opts :: keyword()) :: term()
  def create_observable_gauge({module, _} = meter, name, opts \\ []) do
    module.create_observable_gauge(meter, name, opts)
  end

  @doc """
  Creates an observable (asynchronous) UpDownCounter instrument.
  """
  @spec create_observable_updown_counter(meter :: t(), name :: String.t(), opts :: keyword()) ::
          term()
  def create_observable_updown_counter({module, _} = meter, name, opts \\ []) do
    module.create_observable_updown_counter(meter, name, opts)
  end

  @doc """
  Records a measurement for the named instrument.

  All synchronous instrument recording operations (Counter.add,
  Histogram.record, Gauge.record, UpDownCounter.add) route through
  this function.
  """
  @spec record(meter :: t(), name :: String.t(), value :: number(), attributes :: map()) :: :ok
  def record({module, _} = meter, name, value, attributes \\ %{}) do
    module.record(meter, name, value, attributes)
  end

  @doc """
  Registers a callback for one or more asynchronous instruments.

  The callback will be invoked during metric collection. All instruments
  must belong to the same Meter.
  """
  @spec register_callback(
          meter :: t(),
          instruments :: [term()],
          callback :: function(),
          callback_args :: term(),
          opts :: keyword()
        ) :: :ok
  def register_callback({module, _} = meter, instruments, callback, callback_args, opts \\ []) do
    module.register_callback(meter, instruments, callback, callback_args, opts)
  end

  @doc """
  Returns whether the meter is enabled.
  """
  @spec enabled?(meter :: t(), opts :: keyword()) :: boolean()
  def enabled?({module, _} = meter, opts \\ []) do
    module.enabled?(meter, opts)
  end
end
