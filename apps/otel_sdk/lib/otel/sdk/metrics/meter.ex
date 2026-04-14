defmodule Otel.SDK.Metrics.Meter do
  @moduledoc """
  SDK implementation of the Meter behaviour.

  Handles instrument creation with name validation, duplicate
  detection (case-insensitive), and advisory parameter validation.
  Instruments are stored in a shared ETS table owned by the
  MeterProvider.

  All functions are safe for concurrent use.
  """

  @behaviour Otel.API.Metrics.Meter

  # --- Synchronous Instruments ---

  @impl true
  def create_counter(meter, name, opts) do
    register_instrument(meter, name, :counter, opts)
  end

  @impl true
  def create_histogram(meter, name, opts) do
    register_instrument(meter, name, :histogram, opts)
  end

  @impl true
  def create_gauge(meter, name, opts) do
    register_instrument(meter, name, :gauge, opts)
  end

  @impl true
  def create_updown_counter(meter, name, opts) do
    register_instrument(meter, name, :updown_counter, opts)
  end

  # --- Asynchronous Instruments ---

  @impl true
  def create_observable_counter(meter, name, opts) do
    register_instrument(meter, name, :observable_counter, opts)
  end

  @impl true
  def create_observable_counter(meter, name, _callback, _callback_args, opts) do
    register_instrument(meter, name, :observable_counter, opts)
  end

  @impl true
  def create_observable_gauge(meter, name, opts) do
    register_instrument(meter, name, :observable_gauge, opts)
  end

  @impl true
  def create_observable_gauge(meter, name, _callback, _callback_args, opts) do
    register_instrument(meter, name, :observable_gauge, opts)
  end

  @impl true
  def create_observable_updown_counter(meter, name, opts) do
    register_instrument(meter, name, :observable_updown_counter, opts)
  end

  @impl true
  def create_observable_updown_counter(meter, name, _callback, _callback_args, opts) do
    register_instrument(meter, name, :observable_updown_counter, opts)
  end

  # --- Recording ---

  @impl true
  def record(_meter, _name, _value, _attributes), do: :ok

  # --- Callback Registration ---

  @impl true
  def register_callback(_meter, _instruments, _callback, _callback_args, _opts), do: :ok

  # --- Enabled ---

  @impl true
  def enabled?(_meter, _opts), do: true

  # --- Private ---

  @spec register_instrument(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          kind :: Otel.SDK.Metrics.Instrument.kind(),
          opts :: keyword()
        ) :: Otel.SDK.Metrics.Instrument.t()
  defp register_instrument({_module, config}, name, kind, opts) do
    case Otel.SDK.Metrics.Instrument.validate_name(name) do
      {:ok, validated_name} ->
        do_register(config, validated_name, kind, opts)

      {:error, reason} ->
        :logger.warning(reason, %{domain: [:otel, :metrics]})
        do_register(config, name || "", kind, opts)
    end
  end

  @spec do_register(
          config :: map(),
          name :: String.t(),
          kind :: Otel.SDK.Metrics.Instrument.kind(),
          opts :: keyword()
        ) :: Otel.SDK.Metrics.Instrument.t()
  defp do_register(config, name, kind, opts) do
    unit = Keyword.get(opts, :unit, "") || ""
    description = Keyword.get(opts, :description, "") || ""

    advisory =
      Otel.SDK.Metrics.Instrument.validate_advisory(kind, Keyword.get(opts, :advisory, []))

    instrument = %Otel.SDK.Metrics.Instrument{
      name: name,
      kind: kind,
      unit: unit,
      description: description,
      advisory: advisory,
      scope: config.scope
    }

    key = {config.scope, Otel.SDK.Metrics.Instrument.downcased_name(name)}

    case :ets.insert_new(config.instruments_tab, {key, instrument}) do
      true ->
        instrument

      false ->
        [{^key, existing}] = :ets.lookup(config.instruments_tab, key)

        if not Otel.SDK.Metrics.Instrument.identical?(existing, instrument) do
          :logger.warning(
            "duplicate instrument registration for #{inspect(name)} " <>
              "with different identifying fields, using first-seen",
            %{domain: [:otel, :metrics]}
          )
        end

        existing
    end
  end

  @doc false
  @spec match_views(
          views :: [Otel.SDK.Metrics.View.t()],
          instrument :: Otel.SDK.Metrics.Instrument.t()
        ) :: [Otel.SDK.Metrics.Stream.t()]
  def match_views(views, instrument) do
    streams =
      views
      |> Enum.filter(&Otel.SDK.Metrics.View.matches?(&1, instrument))
      |> Enum.map(&Otel.SDK.Metrics.Stream.from_view(&1, instrument))

    case streams do
      [] ->
        [Otel.SDK.Metrics.Stream.from_instrument(instrument)]

      matched ->
        warn_conflicting_streams(matched)
        matched
    end
  end

  @spec warn_conflicting_streams(streams :: [Otel.SDK.Metrics.Stream.t()]) :: :ok
  defp warn_conflicting_streams(streams) do
    names = Enum.map(streams, & &1.name)

    if length(names) != length(Enum.uniq(names)) do
      :logger.warning(
        "applying Views resulted in conflicting metric stream names",
        %{domain: [:otel, :metrics]}
      )
    end

    :ok
  end
end
