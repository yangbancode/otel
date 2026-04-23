defmodule Otel.SDK.Metrics.Meter do
  @moduledoc """
  SDK implementation of the Meter behaviour.

  Handles instrument creation with case-insensitive duplicate detection.
  Instruments are stored in a shared ETS table owned by the
  MeterProvider.

  All functions are safe for concurrent use.

  ## Design notes

  ### Duplicate registration

  `register_instrument/4` keys instruments by
  `{scope, downcased_name}` and uses `:ets.insert_new/2` so the
  first registration wins. Subsequent `create_*` calls for the same
  key return the already-stored struct unchanged. This satisfies the
  case-insensitive identity requirement of
  `metrics/sdk.md` L945-L958 *"The name of an Instrument is defined to
  be case-insensitive."*.

  The spec's SHOULD-log clauses for identifying-field conflicts
  (`sdk.md` L904-L958, L990) are not currently emitted; a caller
  that re-creates an instrument with a different `kind`, `unit`,
  or `description` gets the original instrument back silently. This
  matches the project's happy-path policy and will be revisited in
  the finalization error-handling pass.

  ### View vs advisory precedence

  When both a matching View and instrument advisory parameters
  influence the same stream aspect, the View wins. Concretely:

  - **Aggregation / bucket boundaries.** If a View explicitly
    specifies an aggregation (e.g. `ExplicitBucketHistogram`),
    advisory `:explicit_bucket_boundaries` are ignored entirely —
    even when the View does not supply custom boundaries
    (`metrics/sdk.md` L1003-L1005). Advisory boundaries only apply
    when no View matched or the matching View uses default
    aggregation (`stream.aggregation == nil`), resolved in
    `Stream.from_view/2` → `Stream.resolve/1` and
    `Stream.from_instrument/1`.
  - **Attribute keys.** `Stream.from_view/2` falls back to advisory
    `:attributes` only when the View has no `:attribute_keys`.

  ### `enabled?/2` with Drop aggregation

  `enabled?/2` returns `false` only when every resolved stream (for
  a registered instrument) or every matching View (for an unregistered
  instrument name) uses `Drop` aggregation. Any non-Drop stream/view
  makes the instrument enabled. This matches `metrics/sdk.md` L1029
  and L1037 and lets user code skip measurement computation cheaply
  when the pipeline would discard the value anyway.
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
  def record(
        %Otel.API.Metrics.Instrument{meter: {_module, config}, name: name, scope: scope},
        value,
        attributes
      ) do
    instrument_key = {scope, Otel.API.Metrics.Instrument.downcased_name(name)}

    case :ets.lookup(config.streams_tab, instrument_key) do
      [] ->
        :ok

      stream_entries ->
        ctx = Otel.API.Ctx.current()
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
        {config.scope, Otel.API.Metrics.Instrument.downcased_name(instrument.name)},
        ref,
        :multi,
        callback,
        callback_args,
        instrument
      })
    end)

    {__MODULE__, {ref, config.callbacks_tab}}
  end

  # --- Enabled ---

  @impl true
  def enabled?(%Otel.API.Metrics.Instrument{meter: {_module, config}, name: name}, _opts) do
    instrument_enabled?(config, name)
  end

  # --- Private ---

  @spec register_instrument(
          meter :: Otel.API.Metrics.Meter.t(),
          name :: String.t(),
          kind :: Otel.API.Metrics.Instrument.kind(),
          opts :: Otel.API.Metrics.Instrument.create_opts()
        ) :: Otel.API.Metrics.Instrument.t()
  defp register_instrument({_module, config} = meter, name, kind, opts) do
    unit = Keyword.get(opts, :unit, "") || ""
    description = Keyword.get(opts, :description, "") || ""
    advisory = Keyword.get(opts, :advisory, [])

    instrument = %Otel.API.Metrics.Instrument{
      meter: meter,
      name: name,
      kind: kind,
      unit: unit,
      description: description,
      advisory: advisory,
      scope: config.scope
    }

    key = {config.scope, Otel.API.Metrics.Instrument.downcased_name(name)}

    case :ets.insert_new(config.instruments_tab, {key, instrument}) do
      true ->
        create_streams(config, instrument)
        instrument

      false ->
        [{^key, existing}] = :ets.lookup(config.instruments_tab, key)
        existing
    end
  end

  @doc false
  @spec match_views(
          views :: [Otel.SDK.Metrics.View.t()],
          instrument :: Otel.API.Metrics.Instrument.t()
        ) :: [Otel.SDK.Metrics.Stream.t()]
  def match_views(views, instrument) do
    streams =
      views
      |> Enum.filter(&Otel.SDK.Metrics.View.matches?(&1, instrument))
      |> Enum.map(&Otel.SDK.Metrics.Stream.from_view(&1, instrument))

    case streams do
      [] -> [Otel.SDK.Metrics.Stream.from_instrument(instrument)]
      matched -> matched
    end
  end

  @spec create_streams(config :: map(), instrument :: Otel.API.Metrics.Instrument.t()) :: :ok
  defp create_streams(config, instrument) do
    base_streams =
      config.views
      |> match_views(instrument)
      |> Enum.map(&Otel.SDK.Metrics.Stream.resolve/1)

    reader_configs = Map.get(config, :reader_configs, [{nil, %{}}])
    instrument_key = {config.scope, Otel.API.Metrics.Instrument.downcased_name(instrument.name)}

    Enum.each(reader_configs, fn {reader_id, reader_opts} ->
      temporality_mapping =
        Map.get(
          reader_opts,
          :temporality_mapping,
          Otel.API.Metrics.Instrument.default_temporality_mapping()
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

  @overflow_attributes %{"otel.metric.overflow" => true}

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
          instrument :: Otel.API.Metrics.Instrument.t(),
          callback :: (term() -> [Otel.API.Metrics.Measurement.t()]),
          callback_args :: term()
        ) :: true
  defp store_callback(config, instrument, callback, callback_args) do
    key = {config.scope, Otel.API.Metrics.Instrument.downcased_name(instrument.name)}
    ref = make_ref()
    :ets.insert(config.callbacks_tab, {key, ref, :single, callback, callback_args, instrument})
  end

  @doc """
  Removes a previously registered callback.

  Called indirectly via `Otel.API.Metrics.Meter.unregister_callback/1`,
  which unwraps the opaque `{module, state}` handle and passes the
  inner state `{ref, callbacks_tab}` here.
  """
  @impl true
  @spec unregister_callback(state :: {reference(), :ets.table()}) :: :ok
  def unregister_callback({ref, callbacks_tab}) do
    :ets.match_delete(callbacks_tab, {:_, ref, :_, :_, :_, :_})
    :ok
  end

  @doc """
  Executes all registered callbacks for the given meter
  config and aggregates the observations into the metrics
  pipeline.

  Called by MetricReader during collection. Two callback
  shapes are supported, distinguished by the shape marker
  stored in each ETS entry:

  - `:single` — inline callback registered via
    `create_observable_*/5` → `store_callback/4`. Callback
    returns `[Measurement.t()]` per
    `metrics/api.md` L441-L442.
  - `:multi` — callback registered via
    `register_callback/5`. Callback returns
    `[{Instrument.t(), Measurement.t()}]` per
    `metrics/api.md` L1302-L1303 + L452-L453 MUST
    (multi-instrument callbacks MUST distinguish the
    instrument for each observation).

  Internally both shapes are normalised to the multi-shape
  (a list of pairs) so `apply_observations/2` has a single
  code path that looks up streams per-instrument.
  """
  @spec run_callbacks(config :: map()) :: :ok
  def run_callbacks(config) do
    callbacks = :ets.tab2list(config.callbacks_tab)

    callbacks
    |> Enum.group_by(fn {_key, ref, _shape, callback, callback_args, _inst} ->
      {ref, callback, callback_args}
    end)
    |> Enum.each(fn {_group_key, entries} ->
      pairs = invoke_callback_and_normalize(entries)
      apply_observations(config, pairs)
    end)
  end

  @spec invoke_callback_and_normalize(entries :: [tuple()]) ::
          [{Otel.API.Metrics.Instrument.t(), Otel.API.Metrics.Measurement.t()}]
  defp invoke_callback_and_normalize([first | _] = entries) do
    {_key, _ref, shape, callback, callback_args, _inst} = first
    result = callback.(callback_args)

    case shape do
      :single ->
        # Inline callback — `result` is `[Measurement.t()]`.
        # There is exactly one ETS entry in the group (one
        # instrument per inline callback); wrap each
        # measurement with that instrument.
        {_, _, _, _, _, instrument} = first
        Enum.map(result, fn measurement -> {instrument, measurement} end)

      :multi ->
        # Multi-instrument callback — `result` is already
        # `[{Instrument, Measurement}]` per spec
        # L1302-L1303. Use as-is. `entries` (with all
        # registered instruments) is not needed here; the
        # callback provides the instrument tag per
        # observation.
        _unused_entries = entries
        result
    end
  end

  @spec apply_observations(
          config :: map(),
          pairs :: [{Otel.API.Metrics.Instrument.t(), Otel.API.Metrics.Measurement.t()}]
        ) :: :ok
  defp apply_observations(config, pairs) do
    ctx = Otel.API.Ctx.current()
    now = System.system_time(:nanosecond)

    Enum.each(pairs, fn {%Otel.API.Metrics.Instrument{} = instrument,
                         %Otel.API.Metrics.Measurement{
                           value: value,
                           attributes: attributes
                         }} ->
      streams = lookup_streams_for_instrument(config, instrument)

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
          time :: non_neg_integer(),
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

  @spec instrument_enabled?(config :: map(), name :: String.t()) :: boolean()
  defp instrument_enabled?(config, name) do
    instrument_key =
      {config.scope, Otel.API.Metrics.Instrument.downcased_name(name)}

    case :ets.lookup(config.streams_tab, instrument_key) do
      [] ->
        not all_views_drop?(config.views, name)

      streams ->
        not Enum.all?(streams, fn {_key, stream} ->
          stream.aggregation == Otel.SDK.Metrics.Aggregation.Drop
        end)
    end
  end

  @spec all_views_drop?(views :: [Otel.SDK.Metrics.View.t()], name :: String.t()) :: boolean()
  defp all_views_drop?(views, name) do
    dummy = %Otel.API.Metrics.Instrument{name: name}

    matching =
      Enum.filter(views, &Otel.SDK.Metrics.View.matches?(&1, dummy))

    case matching do
      [] ->
        false

      matched ->
        Enum.all?(matched, fn view ->
          Map.get(view.config, :aggregation) == Otel.SDK.Metrics.Aggregation.Drop
        end)
    end
  end

  @spec lookup_streams_for_instrument(
          config :: map(),
          instrument :: Otel.API.Metrics.Instrument.t()
        ) :: [Otel.SDK.Metrics.Stream.t()]
  defp lookup_streams_for_instrument(config, %Otel.API.Metrics.Instrument{
         scope: scope,
         name: name
       }) do
    instrument_key = {scope, Otel.API.Metrics.Instrument.downcased_name(name)}

    config.streams_tab
    |> :ets.lookup(instrument_key)
    |> Enum.map(fn {_key, stream} -> stream end)
  end
end
