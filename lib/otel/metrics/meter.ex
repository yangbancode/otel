defmodule Otel.Metrics.Meter do
  @moduledoc """
  SDK implementation of the `Otel.Metrics.Meter`
  behaviour (`metrics/sdk.md` §Meter L870-L943).

  Handles instrument creation with case-insensitive duplicate detection.
  Instruments are stored in the `Otel.Metrics.InstrumentsStorage`
  ETS table; the GenServer that owns it is started by
  `Otel.Application.start/2`.

  All functions are safe for concurrent use, satisfying spec
  `metrics/sdk.md` L1351-L1352 — *"Instrument — synchronous and
  asynchronous instrument operations MUST be safe to be called
  concurrently."*

  ## Public API

  | Callback | Role |
  |---|---|
  | `create_*` (counter, histogram, gauge, updown_counter) | **SDK** (OTel API MUST) — `metrics/api.md` §Instruments |
  | `record/3` | **SDK** (OTel API MUST) — synchronous instrument measurement |

  Asynchronous (Observable) instruments are intentionally not
  implemented — minikube targets the BEAM-native `:telemetry`
  ecosystem for poll-based measurements (see project memory
  `project_pivot_beginner_focused.md`). A telemetry-handler
  bridge (analogous to `Otel.LoggerHandler`) is planned but not
  part of this module.

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

  Each instrument carries a hardcoded `aggregation_module`
  derived from `:kind` at registration (Counter →
  `Sum`, Histogram → `ExplicitBucketHistogram`, etc.).
  `metrics/sdk.md` L1003-L1005 advisory
  `:explicit_bucket_boundaries` flow into the histogram
  aggregation's `aggregation_opts` when present.

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

  # --- Recording ---

  def record(%Otel.Metrics.Instrument{config: config} = instrument, value, attributes) do
    instrument_key =
      {instrument.scope, Otel.Metrics.Instrument.downcased_name(instrument.name)}

    case :ets.lookup(config.instruments_tab, instrument_key) do
      [] ->
        :ok

      [{^instrument_key, registered}] ->
        ctx = Otel.Ctx.current()
        now = System.system_time(:nanosecond)

        agg_key = {registered.name, registered.scope, attributes}
        agg_key = maybe_overflow(config.metrics_tab, registered, agg_key)

        registered.aggregation_module.aggregate(
          config.metrics_tab,
          agg_key,
          value,
          registered.aggregation_opts
        )

        offer_exemplar(config, registered, agg_key, value, now, %{}, ctx)
    end
  end

  # --- Private ---

  @doc false
  # SDK-internal (test) — register an instrument under a custom
  # `meter_config` map. The public `create_*/2` paths route
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
    aggregation_module = Otel.Metrics.Aggregation.default_for(kind)

    instrument =
      Otel.Metrics.Instrument.new(%{
        config: config,
        name: name,
        kind: kind,
        unit: unit,
        description: description,
        advisory: advisory,
        scope: config.scope,
        aggregation_module: aggregation_module,
        aggregation_opts: aggregation_opts(advisory),
        # Spec metrics/sdk.md L1129-L1133 — default
        # CardinalityLimit is 2000 per stream.
        cardinality_limit: 2000,
        exemplar_reservoir: default_reservoir(aggregation_module)
      })

    key = {config.scope, Otel.Metrics.Instrument.downcased_name(name)}

    case :ets.insert_new(config.instruments_tab, {key, instrument}) do
      true ->
        instrument

      false ->
        [{^key, existing}] = :ets.lookup(config.instruments_tab, key)
        warn_duplicate_instrument(existing, instrument)
        existing
    end
  end

  @spec aggregation_opts(advisory :: Otel.Metrics.Instrument.advisory()) :: map()
  defp aggregation_opts(advisory) do
    case Keyword.get(advisory, :explicit_bucket_boundaries) do
      nil -> %{}
      boundaries -> %{boundaries: boundaries}
    end
  end

  @spec default_reservoir(aggregation_module :: module()) :: module()
  defp default_reservoir(Otel.Metrics.Aggregation.ExplicitBucketHistogram),
    do: Otel.Metrics.Exemplar.Reservoir.AlignedHistogramBucket

  defp default_reservoir(_aggregation),
    do: Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize

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

  @overflow_attributes %{"otel.metric.overflow" => true}

  @spec maybe_overflow(
          metrics_tab :: :ets.table(),
          instrument :: Otel.Metrics.Instrument.t(),
          agg_key :: term()
        ) :: term()
  defp maybe_overflow(metrics_tab, instrument, {stream_name, scope, _attrs} = agg_key) do
    if :ets.member(metrics_tab, agg_key) do
      agg_key
    else
      limit = instrument.cardinality_limit
      current = count_stream_keys(metrics_tab, stream_name, scope)

      if current >= limit do
        {stream_name, scope, @overflow_attributes}
      else
        agg_key
      end
    end
  end

  @spec count_stream_keys(
          tab :: :ets.table(),
          stream_name :: String.t(),
          scope :: Otel.InstrumentationScope.t()
        ) :: non_neg_integer()
  defp count_stream_keys(tab, stream_name, scope) do
    :ets.foldl(
      fn entry, acc ->
        case elem(entry, 0) do
          {^stream_name, ^scope, _} -> acc + 1
          _ -> acc
        end
      end,
      0,
      tab
    )
  end

  @spec offer_exemplar(
          config :: map(),
          instrument :: Otel.Metrics.Instrument.t(),
          agg_key :: term(),
          value :: number(),
          time :: non_neg_integer(),
          filtered_attrs :: map(),
          ctx :: Otel.Ctx.t()
        ) :: :ok
  defp offer_exemplar(config, instrument, agg_key, value, time, filtered_attrs, ctx) do
    reservoir = get_reservoir(config.exemplars_tab, instrument, agg_key)

    updated =
      Otel.Metrics.Exemplar.Reservoir.offer(reservoir, value, time, filtered_attrs, ctx)

    put_reservoir(config.exemplars_tab, agg_key, updated)
  end

  @spec get_reservoir(
          exemplars_tab :: :ets.table(),
          instrument :: Otel.Metrics.Instrument.t(),
          agg_key :: term()
        ) :: {module(), term()} | nil
  defp get_reservoir(exemplars_tab, instrument, agg_key) do
    case :ets.lookup(exemplars_tab, agg_key) do
      [{^agg_key, reservoir}] ->
        reservoir

      [] ->
        case instrument.exemplar_reservoir do
          nil ->
            nil

          module ->
            opts = reservoir_opts(instrument)
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

  @spec reservoir_opts(instrument :: Otel.Metrics.Instrument.t()) :: map()
  defp reservoir_opts(instrument) do
    case instrument.aggregation_module do
      Otel.Metrics.Aggregation.ExplicitBucketHistogram ->
        boundaries =
          Map.get(
            instrument.aggregation_opts,
            :boundaries,
            Otel.Metrics.Aggregation.ExplicitBucketHistogram.default_boundaries()
          )

        %{boundaries: boundaries}

      _ ->
        %{size: 1}
    end
  end
end
