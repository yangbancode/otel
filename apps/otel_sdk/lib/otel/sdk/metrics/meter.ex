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
  def create_observable_counter({_module, config} = meter, name, callback, callback_args, opts) do
    instrument = register_instrument(meter, name, :observable_counter, opts)
    store_callback(config, instrument, callback, callback_args)
    instrument
  end

  @impl true
  def create_observable_gauge(meter, name, opts) do
    register_instrument(meter, name, :observable_gauge, opts)
  end

  @impl true
  def create_observable_gauge({_module, config} = meter, name, callback, callback_args, opts) do
    instrument = register_instrument(meter, name, :observable_gauge, opts)
    store_callback(config, instrument, callback, callback_args)
    instrument
  end

  @impl true
  def create_observable_updown_counter(meter, name, opts) do
    register_instrument(meter, name, :observable_updown_counter, opts)
  end

  @impl true
  def create_observable_updown_counter(
        {_module, config} = meter,
        name,
        callback,
        callback_args,
        opts
      ) do
    instrument = register_instrument(meter, name, :observable_updown_counter, opts)
    store_callback(config, instrument, callback, callback_args)
    instrument
  end

  # --- Recording ---

  @impl true
  def record({_module, config}, name, value, attributes) do
    instrument_key = {config.scope, Otel.SDK.Metrics.Instrument.downcased_name(name)}

    case :ets.lookup(config.streams_tab, instrument_key) do
      [] ->
        :ok

      stream_entries ->
        ctx = Otel.API.Ctx.get_current()
        now = System.system_time(:nanosecond)

        Enum.each(stream_entries, fn {_key, stream} ->
          filtered_attrs = filter_stream_attributes(stream, attributes)
          agg_key = {stream.name, stream.instrument.scope, stream.reader_id, filtered_attrs}
          agg_key = maybe_overflow(config.metrics_tab, stream, agg_key)

          stream.aggregation.aggregate(
            config.metrics_tab,
            agg_key,
            value,
            stream.aggregation_options
          )

          dropped_attrs = Map.drop(attributes, Map.keys(filtered_attrs))
          offer_exemplar(config, stream, agg_key, value, now, dropped_attrs, ctx)
        end)
    end
  end

  # --- Callback Registration ---

  @impl true
  def register_callback({_module, config}, instruments, callback, callback_args, _opts) do
    ref = make_ref()

    Enum.each(instruments, fn instrument ->
      :ets.insert(config.callbacks_tab, {
        {config.scope, Otel.SDK.Metrics.Instrument.downcased_name(instrument.name)},
        ref,
        callback,
        callback_args,
        instrument
      })
    end)

    {ref, config.callbacks_tab}
  end

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
        create_streams(config, instrument)
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

  @spec create_streams(config :: map(), instrument :: Otel.SDK.Metrics.Instrument.t()) :: :ok
  defp create_streams(config, instrument) do
    base_streams =
      config.views
      |> match_views(instrument)
      |> Enum.map(&Otel.SDK.Metrics.Stream.resolve/1)

    reader_configs = Map.get(config, :reader_configs, [{nil, %{}}])
    instrument_key = {config.scope, Otel.SDK.Metrics.Instrument.downcased_name(instrument.name)}

    Enum.each(reader_configs, fn {reader_id, reader_opts} ->
      temporality_mapping =
        Map.get(
          reader_opts,
          :temporality_mapping,
          Otel.SDK.Metrics.Instrument.default_temporality_mapping()
        )

      temporality = Map.get(temporality_mapping, instrument.kind, :cumulative)

      Enum.each(base_streams, fn stream ->
        reader_stream = %{stream | temporality: temporality, reader_id: reader_id}
        :ets.insert(config.streams_tab, {instrument_key, reader_stream})
      end)
    end)
  end

  @spec filter_stream_attributes(
          stream :: Otel.SDK.Metrics.Stream.t(),
          attributes :: map()
        ) :: map()
  defp filter_stream_attributes(stream, attributes) do
    case stream.attribute_keys do
      {:include, keys} -> Map.take(attributes, keys)
      {:exclude, keys} -> Map.drop(attributes, keys)
      nil -> attributes
    end
  end

  @overflow_attributes %{:"otel.metric.overflow" => true}

  @spec maybe_overflow(
          metrics_tab :: :ets.table(),
          stream :: Otel.SDK.Metrics.Stream.t(),
          agg_key :: term()
        ) :: term()
  defp maybe_overflow(metrics_tab, stream, {stream_name, scope, reader_id, _attrs} = agg_key) do
    if :ets.member(metrics_tab, agg_key) do
      agg_key
    else
      limit = stream.aggregation_cardinality_limit
      current = count_stream_keys(metrics_tab, stream_name, scope, reader_id)

      if current >= limit do
        {stream_name, scope, reader_id, @overflow_attributes}
      else
        agg_key
      end
    end
  end

  @spec count_stream_keys(
          metrics_tab :: :ets.table(),
          stream_name :: String.t(),
          scope :: Otel.API.InstrumentationScope.t(),
          reader_id :: reference() | nil
        ) :: non_neg_integer()
  defp count_stream_keys(metrics_tab, stream_name, scope, reader_id) do
    :ets.foldl(
      fn entry, acc ->
        case elem(entry, 0) do
          {^stream_name, ^scope, ^reader_id, _} -> acc + 1
          _ -> acc
        end
      end,
      0,
      metrics_tab
    )
  end

  @spec store_callback(
          config :: map(),
          instrument :: Otel.SDK.Metrics.Instrument.t(),
          callback :: function(),
          callback_args :: term()
        ) :: true
  defp store_callback(config, instrument, callback, callback_args) do
    key = {config.scope, Otel.SDK.Metrics.Instrument.downcased_name(instrument.name)}
    ref = make_ref()
    :ets.insert(config.callbacks_tab, {key, ref, callback, callback_args, instrument})
  end

  @doc """
  Removes a previously registered callback.

  Accepts the `{ref, callbacks_tab}` tuple returned by `register_callback/5`.
  """
  @spec unregister_callback(registration :: {reference(), :ets.table()}) :: :ok
  def unregister_callback({ref, callbacks_tab}) do
    :ets.match_delete(callbacks_tab, {:_, ref, :_, :_, :_})
    :ok
  end

  @doc """
  Executes all registered callbacks for the given meter config and
  aggregates the observations into the metrics pipeline.

  Called by MetricReader during collection. Each callback returns
  a list of `{value, attributes}` tuples.
  """
  @spec run_callbacks(config :: map()) :: :ok
  def run_callbacks(config) do
    callbacks = :ets.tab2list(config.callbacks_tab)

    callbacks
    |> Enum.group_by(fn {_key, ref, callback, callback_args, _inst} ->
      {ref, callback, callback_args}
    end)
    |> Enum.each(fn {{_ref, callback, callback_args}, entries} ->
      observations = callback.(callback_args)
      apply_observations(config, entries, observations)
    end)
  end

  @spec apply_observations(
          config :: map(),
          entries :: [tuple()],
          observations :: [{number(), map()}]
        ) :: :ok
  defp apply_observations(config, entries, observations) do
    streams = lookup_callback_streams(config, entries)
    ctx = Otel.API.Ctx.get_current()
    now = System.system_time(:nanosecond)

    Enum.each(observations, fn {value, attributes} ->
      Enum.each(streams, fn stream ->
        filtered_attrs = filter_stream_attributes(stream, attributes)
        agg_key = {stream.name, stream.instrument.scope, stream.reader_id, filtered_attrs}
        agg_key = maybe_overflow(config.metrics_tab, stream, agg_key)

        stream.aggregation.aggregate(
          config.metrics_tab,
          agg_key,
          value,
          stream.aggregation_options
        )

        dropped_attrs = Map.drop(attributes, Map.keys(filtered_attrs))
        offer_exemplar(config, stream, agg_key, value, now, dropped_attrs, ctx)
      end)
    end)
  end

  @spec offer_exemplar(
          config :: map(),
          stream :: Otel.SDK.Metrics.Stream.t(),
          agg_key :: term(),
          value :: number(),
          time :: integer(),
          filtered_attrs :: map(),
          ctx :: Otel.API.Ctx.t()
        ) :: :ok
  defp offer_exemplar(config, stream, agg_key, value, time, filtered_attrs, ctx) do
    filter = Map.get(config, :exemplar_filter, :trace_based)
    reservoir = get_reservoir(config.exemplars_tab, stream, agg_key)

    updated =
      Otel.SDK.Metrics.Exemplar.Reservoir.offer_to(
        reservoir,
        filter,
        value,
        time,
        filtered_attrs,
        ctx
      )

    put_reservoir(config.exemplars_tab, agg_key, updated)
  end

  @spec get_reservoir(
          exemplars_tab :: :ets.table(),
          stream :: Otel.SDK.Metrics.Stream.t(),
          agg_key :: term()
        ) :: {module(), term()} | nil
  defp get_reservoir(exemplars_tab, stream, agg_key) do
    case :ets.lookup(exemplars_tab, agg_key) do
      [{^agg_key, reservoir}] ->
        reservoir

      [] ->
        case stream.exemplar_reservoir do
          nil ->
            nil

          module ->
            opts = reservoir_opts(stream)
            {module, module.new(opts)}
        end
    end
  end

  @spec put_reservoir(exemplars_tab :: :ets.table(), agg_key :: term(), reservoir :: term()) ::
          :ok
  defp put_reservoir(_exemplars_tab, _agg_key, nil), do: :ok

  defp put_reservoir(exemplars_tab, agg_key, reservoir) do
    :ets.insert(exemplars_tab, {agg_key, reservoir})
    :ok
  end

  @spec reservoir_opts(stream :: Otel.SDK.Metrics.Stream.t()) :: map()
  defp reservoir_opts(stream) do
    case stream.aggregation do
      Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram ->
        boundaries =
          Map.get(
            stream.aggregation_options,
            :boundaries,
            Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram.default_boundaries()
          )

        %{boundaries: boundaries}

      _ ->
        %{size: 1}
    end
  end

  @spec lookup_callback_streams(config :: map(), entries :: [tuple()]) ::
          [Otel.SDK.Metrics.Stream.t()]
  defp lookup_callback_streams(config, entries) do
    Enum.flat_map(entries, fn {instrument_key, _ref, _cb, _args, _instrument} ->
      config.streams_tab
      |> :ets.lookup(instrument_key)
      |> Enum.map(fn {_key, stream} -> stream end)
    end)
  end
end
