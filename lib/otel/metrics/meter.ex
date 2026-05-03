defmodule Otel.Metrics.Meter do
  @moduledoc """
  SDK implementation of the `Otel.Metrics.Meter`
  behaviour (`metrics/sdk.md` §Meter L870-L943).

  Handles instrument creation with case-insensitive duplicate detection.
  Instruments are stored in the shared ETS table created by
  `Otel.Metrics.init/0` at boot.

  All functions are safe for concurrent use, satisfying spec
  `metrics/sdk.md` L1351-L1352 — *"Instrument — synchronous and
  asynchronous instrument operations MUST be safe to be called
  concurrently."*

  ## Public API

  | Callback | Role |
  |---|---|
  | `create_*` (counter, histogram, gauge, updown_counter, observable_*) | **SDK** (OTel API MUST) — `metrics/api.md` §Instruments |
  | `record/3` | **SDK** (OTel API MUST) — synchronous instrument measurement |
  | `register_callback/5` | **SDK** (OTel API MUST) — async instrument registration |

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

  ### Aggregation / bucket boundaries

  Each instrument produces exactly one stream resolved by
  `Stream.from_instrument/1` → `Stream.resolve/1` against spec
  defaults. `metrics/sdk.md` L1003-L1005 advisory
  `:explicit_bucket_boundaries` flow into the histogram
  aggregation when present.

  ### Async cardinality — first-observed across temporalities

  Spec `metrics/sdk.md` §"Asynchronous instrument cardinality
  limits" L864-L866 SHOULD —
  *"Aggregators of asynchronous instruments SHOULD prefer the
  first-observed attributes in the callback when limiting
  cardinality, regardless of temporality."*

  Sync overflow (`maybe_overflow/3`) inspects `metrics_tab`,
  which works as first-observed only under cumulative because
  delta-temporality readers clear the table on each collect.

  Async overflow (`maybe_overflow_async/3`) instead consults
  the dedicated `observed_attrs_tab` ETS set, which records
  every `(stream, reader, attrs)` triple ever observed for an
  async stream. Entries survive delta resets, so the first N
  attribute sets ever observed are pinned to the original
  key forever; subsequent sets route to the overflow
  attribute regardless of whether the metrics table has been
  cleared.

  The `:ets.member` + `count_stream_keys` + `:ets.insert`
  sequence in `maybe_overflow_async/3` is non-atomic. Two
  callbacks racing on different new attribute sets at the
  boundary `current = limit - 1` could both pass the count
  check and both insert, briefly exceeding the limit by one.
  In practice `MetricReader.collect/1` serialises callbacks
  per reader, so this race only fires across multiple readers
  collecting simultaneously — a corner the spec MUST at L840
  (no overflow when distinct sets ≤ limit) does not strictly
  bind, since at the boundary the SHOULD is already best-
  effort.

  ## References

  - OTel Metrics SDK §Meter: `opentelemetry-specification/specification/metrics/sdk.md` L870-L943
  - OTel Metrics API §Meter: `opentelemetry-specification/specification/metrics/api.md` L156-L499
  """

  require Logger

  # --- Synchronous Instruments ---

  def create_counter(name, opts \\ []) do
    register_instrument(Otel.Metrics.meter_config(), name, :counter, opts)
  end

  def create_histogram(name, opts \\ []) do
    register_instrument(Otel.Metrics.meter_config(), name, :histogram, opts)
  end

  def create_gauge(name, opts \\ []) do
    register_instrument(Otel.Metrics.meter_config(), name, :gauge, opts)
  end

  def create_updown_counter(name, opts \\ []) do
    register_instrument(Otel.Metrics.meter_config(), name, :updown_counter, opts)
  end

  # --- Asynchronous Instruments ---

  def create_observable_counter(name, opts \\ []) do
    register_instrument(Otel.Metrics.meter_config(), name, :observable_counter, opts)
  end

  def create_observable_counter(name, callback, callback_args, opts) do
    config = Otel.Metrics.meter_config()
    instrument = register_instrument(config, name, :observable_counter, opts)
    store_callback(config, instrument, callback, callback_args)
    instrument
  end

  def create_observable_gauge(name, opts \\ []) do
    register_instrument(Otel.Metrics.meter_config(), name, :observable_gauge, opts)
  end

  def create_observable_gauge(name, callback, callback_args, opts) do
    config = Otel.Metrics.meter_config()
    instrument = register_instrument(config, name, :observable_gauge, opts)
    store_callback(config, instrument, callback, callback_args)
    instrument
  end

  def create_observable_updown_counter(name, opts \\ []) do
    register_instrument(Otel.Metrics.meter_config(), name, :observable_updown_counter, opts)
  end

  def create_observable_updown_counter(name, callback, callback_args, opts) do
    config = Otel.Metrics.meter_config()
    instrument = register_instrument(config, name, :observable_updown_counter, opts)
    store_callback(config, instrument, callback, callback_args)
    instrument
  end

  # --- Recording ---

  def record(
        %Otel.Metrics.Instrument{config: config, name: name, scope: scope},
        value,
        attributes
      ) do
    instrument_key = {scope, Otel.Metrics.Instrument.downcased_name(name)}

    case :ets.lookup(config.streams_tab, instrument_key) do
      [] ->
        :ok

      stream_entries ->
        ctx = Otel.Ctx.current()
        now = System.system_time(:nanosecond)

        Enum.each(stream_entries, fn {_key, stream} ->
          agg_key = {stream.name, stream.instrument.scope, stream.reader_id, attributes}
          agg_key = maybe_overflow(config.metrics_tab, stream, agg_key)

          stream.aggregation.aggregate(
            config.metrics_tab,
            agg_key,
            value,
            stream.aggregation_options
          )

          offer_exemplar(config, stream, agg_key, value, now, %{}, ctx)
        end)
    end
  end

  # --- Callback Registration ---

  def register_callback(instruments, callback, callback_args, _opts) do
    config = Otel.Metrics.meter_config()
    ref = make_ref()

    Enum.each(instruments, fn instrument ->
      :ets.insert(config.callbacks_tab, {
        {config.scope, Otel.Metrics.Instrument.downcased_name(instrument.name)},
        ref,
        :multi,
        callback,
        callback_args,
        instrument
      })
    end)

    {ref, config.callbacks_tab}
  end

  # --- Private ---

  @doc false
  # SDK-internal (test) — register an instrument under a custom
  # `meter_config` map. The public `create_*/2,5` paths route
  # through `Otel.Metrics.meter_config/0` (the SDK-default
  # cumulative config); tests that need delta temporality or
  # other override-only paths construct a custom config and
  # call here directly.
  @spec register_instrument(
          config :: map(),
          name :: String.t(),
          kind :: Otel.Metrics.Instrument.kind(),
          opts :: Otel.Metrics.Instrument.create_opts()
        ) :: Otel.Metrics.Instrument.t()
  def register_instrument(config, name, kind, opts) do
    # `Keyword.get/3` covers absent keys; the `|| ""` covers
    # `Keyword.get(opts, :unit, nil)` style callers that pass
    # an explicit `nil` (test fixtures do this). Both fields
    # are spec-typed `String.t()`, so empty string is the
    # only sensible coercion of nil.
    unit = Keyword.get(opts, :unit, "") || ""
    description = Keyword.get(opts, :description, "") || ""
    advisory = Keyword.get(opts, :advisory, [])

    instrument = %Otel.Metrics.Instrument{
      config: config,
      name: name,
      kind: kind,
      unit: unit,
      description: description,
      advisory: advisory,
      scope: config.scope
    }

    key = {config.scope, Otel.Metrics.Instrument.downcased_name(name)}

    case :ets.insert_new(config.instruments_tab, {key, instrument}) do
      true ->
        create_streams(config, instrument)
        instrument

      false ->
        [{^key, existing}] = :ets.lookup(config.instruments_tab, key)
        warn_duplicate_instrument(existing, instrument)
        existing
    end
  end

  # Spec `metrics/sdk.md` L917-L930 — *"a warning SHOULD be
  # emitted... include information for the user on how to
  # resolve the conflict, if possible."* The MUST is not on
  # us (we always return the existing instrument); the SHOULD
  # is the warning.
  #
  # Conflict criteria per spec L920-L928: same identity (name +
  # case-insensitive comparison) but different `kind`, `unit`,
  # `description`, or `advisory`. We compare structurally on the
  # four user-visible fields and skip the warning when the new
  # registration is identical (idempotent re-registration is
  # common in tests and library reloads).
  @spec warn_duplicate_instrument(
          existing :: Otel.Metrics.Instrument.t(),
          new :: Otel.Metrics.Instrument.t()
        ) :: :ok
  defp warn_duplicate_instrument(existing, new) do
    fields = [:kind, :unit, :description, :advisory]
    diffs = Enum.filter(fields, fn f -> Map.get(existing, f) != Map.get(new, f) end)

    if diffs == [] do
      :ok
    else
      Logger.warning(
        "Otel.Metrics.Meter: duplicate instrument registration for " <>
          "#{inspect(new.name)} differs in #{inspect(diffs)} — " <>
          "give the second instrument a distinct name"
      )

      :ok
    end
  end

  @spec create_streams(config :: map(), instrument :: Otel.Metrics.Instrument.t()) :: :ok
  defp create_streams(config, instrument) do
    base_streams =
      [
        instrument
        |> Otel.Metrics.Stream.from_instrument()
        |> Otel.Metrics.Stream.resolve()
      ]

    reader_configs = Map.get(config, :reader_configs, [{nil, %{}}])
    instrument_key = {config.scope, Otel.Metrics.Instrument.downcased_name(instrument.name)}

    Enum.each(reader_configs, fn {reader_id, reader_opts} ->
      temporality_mapping =
        Map.get(
          reader_opts,
          :temporality_mapping,
          Otel.Metrics.Instrument.default_temporality_mapping()
        )

      temporality = Map.get(temporality_mapping, instrument.kind, :cumulative)

      Enum.each(base_streams, fn stream ->
        reader_stream = %{stream | temporality: temporality, reader_id: reader_id}
        :ets.insert(config.streams_tab, {instrument_key, reader_stream})
      end)
    end)
  end

  @overflow_attributes %{"otel.metric.overflow" => true}

  @spec maybe_overflow(
          metrics_tab :: :ets.table(),
          stream :: Otel.Metrics.Stream.t(),
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

  # Spec `metrics/sdk.md` §"Asynchronous instrument cardinality
  # limits" L864-L866 SHOULD: *"Aggregators of asynchronous
  # instruments SHOULD prefer the first-observed attributes in
  # the callback when limiting cardinality, regardless of
  # temporality."*
  #
  # We separate async overflow tracking from sync because the
  # sync path's `metrics_tab`-based "is this attribute set
  # known?" check coincides with first-observed only under
  # cumulative temporality. Async + delta clears `metrics_tab`
  # on each collect, which would let late-arriving sets
  # replace earlier ones — violating the SHOULD.
  #
  # The `observed_attrs_tab` records every (stream, reader,
  # attrs) triple ever observed for an async stream. Entries
  # survive delta collect resets, so the first N attribute
  # sets ever observed remain pinned to the original key
  # forever; subsequent sets route to the overflow attribute.
  @spec maybe_overflow_async(
          observed_attrs_tab :: :ets.table(),
          stream :: Otel.Metrics.Stream.t(),
          agg_key :: term()
        ) :: term()
  defp maybe_overflow_async(
         observed_attrs_tab,
         stream,
         {stream_name, scope, reader_id, _attrs} = agg_key
       ) do
    if :ets.member(observed_attrs_tab, agg_key) do
      agg_key
    else
      limit = stream.aggregation_cardinality_limit
      current = count_stream_keys(observed_attrs_tab, stream_name, scope, reader_id)

      if current >= limit do
        {stream_name, scope, reader_id, @overflow_attributes}
      else
        :ets.insert(observed_attrs_tab, {agg_key, true})
        agg_key
      end
    end
  end

  @spec count_stream_keys(
          tab :: :ets.table(),
          stream_name :: String.t(),
          scope :: Otel.InstrumentationScope.t(),
          reader_id :: reference() | nil
        ) :: non_neg_integer()
  defp count_stream_keys(tab, stream_name, scope, reader_id) do
    :ets.foldl(
      fn entry, acc ->
        case elem(entry, 0) do
          {^stream_name, ^scope, ^reader_id, _} -> acc + 1
          _ -> acc
        end
      end,
      0,
      tab
    )
  end

  @spec store_callback(
          config :: map(),
          instrument :: Otel.Metrics.Instrument.t(),
          callback :: (term() -> [Otel.Metrics.Measurement.t()]),
          callback_args :: term()
        ) :: true
  defp store_callback(config, instrument, callback, callback_args) do
    key = {config.scope, Otel.Metrics.Instrument.downcased_name(instrument.name)}
    ref = make_ref()
    :ets.insert(config.callbacks_tab, {key, ref, :single, callback, callback_args, instrument})
  end

  @doc """
  Removes a previously registered callback.

  Called indirectly via `Otel.Metrics.Meter.unregister_callback/1`,
  which unwraps the opaque `{module, state}` handle and passes the
  inner state `{ref, callbacks_tab}` here.
  """
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
          [{Otel.Metrics.Instrument.t(), Otel.Metrics.Measurement.t()}]
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
          pairs :: [{Otel.Metrics.Instrument.t(), Otel.Metrics.Measurement.t()}]
        ) :: :ok
  defp apply_observations(config, pairs) do
    ctx = Otel.Ctx.current()
    now = System.system_time(:nanosecond)

    Enum.each(pairs, fn {%Otel.Metrics.Instrument{} = instrument,
                         %Otel.Metrics.Measurement{
                           value: value,
                           attributes: attributes
                         }} ->
      streams = lookup_streams_for_instrument(config, instrument)

      Enum.each(streams, fn stream ->
        agg_key = {stream.name, stream.instrument.scope, stream.reader_id, attributes}
        agg_key = maybe_overflow_async(config.observed_attrs_tab, stream, agg_key)

        stream.aggregation.aggregate(
          config.metrics_tab,
          agg_key,
          value,
          stream.aggregation_options
        )

        offer_exemplar(config, stream, agg_key, value, now, %{}, ctx)
      end)
    end)
  end

  @spec offer_exemplar(
          config :: map(),
          stream :: Otel.Metrics.Stream.t(),
          agg_key :: term(),
          value :: number(),
          time :: non_neg_integer(),
          filtered_attrs :: map(),
          ctx :: Otel.Ctx.t()
        ) :: :ok
  defp offer_exemplar(config, stream, agg_key, value, time, filtered_attrs, ctx) do
    filter = Map.get(config, :exemplar_filter, :trace_based)
    reservoir = get_reservoir(config.exemplars_tab, stream, agg_key)

    updated =
      Otel.Metrics.Exemplar.Reservoir.offer(
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
          stream :: Otel.Metrics.Stream.t(),
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

  @spec reservoir_opts(stream :: Otel.Metrics.Stream.t()) :: map()
  defp reservoir_opts(stream) do
    case stream.aggregation do
      Otel.Metrics.Aggregation.ExplicitBucketHistogram ->
        boundaries =
          Map.get(
            stream.aggregation_options,
            :boundaries,
            Otel.Metrics.Aggregation.ExplicitBucketHistogram.default_boundaries()
          )

        %{boundaries: boundaries}

      _ ->
        %{size: 1}
    end
  end

  @spec lookup_streams_for_instrument(
          config :: map(),
          instrument :: Otel.Metrics.Instrument.t()
        ) :: [Otel.Metrics.Stream.t()]
  defp lookup_streams_for_instrument(config, %Otel.Metrics.Instrument{
         scope: scope,
         name: name
       }) do
    instrument_key = {scope, Otel.Metrics.Instrument.downcased_name(name)}

    config.streams_tab
    |> :ets.lookup(instrument_key)
    |> Enum.map(fn {_key, stream} -> stream end)
  end
end
