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

  `register_instrument/3` keys instruments by
  `downcased_name` and uses `:ets.insert_new/2` so the
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
    register_instrument(name, :counter, opts)
  end

  def create_histogram(name, opts \\ []) do
    register_instrument(name, :histogram, opts)
  end

  def create_gauge(name, opts \\ []) do
    register_instrument(name, :gauge, opts)
  end

  def create_updown_counter(name, opts \\ []) do
    register_instrument(name, :updown_counter, opts)
  end

  # --- Recording ---

  def record(%Otel.Metrics.Instrument{} = instrument, value, attributes) do
    instrument_key = Otel.Metrics.Instrument.downcased_name(instrument.name)

    case :ets.lookup(Otel.Metrics.InstrumentsStorage, instrument_key) do
      [] ->
        :ok

      [{^instrument_key, registered}] ->
        ctx = Otel.Ctx.current()
        now = System.system_time(:nanosecond)

        agg_key = {registered.name, attributes}
        agg_key = maybe_overflow(registered, agg_key)

        registered.aggregation_module.aggregate(
          Otel.Metrics.MetricsStorage,
          agg_key,
          value,
          registered.aggregation_opts
        )

        offer_exemplar(registered, agg_key, value, now, %{}, ctx)
    end
  end

  # --- Private ---

  @spec register_instrument(
          name :: String.t(),
          kind :: Otel.Metrics.Instrument.kind(),
          opts :: Otel.Metrics.Instrument.create_opts()
        ) :: Otel.Metrics.Instrument.t()
  defp register_instrument(name, kind, opts) do
    # `Keyword.get/3` covers absent keys; the `|| ""` covers
    # `Keyword.get(opts, :unit, nil)` style callers that pass
    # an explicit `nil` (test fixtures do this). Both fields
    # are spec-typed `String.t()`, so empty string is the
    # only sensible coercion of nil.
    unit = Keyword.get(opts, :unit, "") || ""
    description = Keyword.get(opts, :description, "") || ""
    advisory = Keyword.get(opts, :advisory, [])

    instrument =
      Otel.Metrics.Instrument.new(%{
        name: name,
        kind: kind,
        unit: unit,
        description: description,
        advisory: advisory
      })

    key = Otel.Metrics.Instrument.downcased_name(name)

    case :ets.insert_new(Otel.Metrics.InstrumentsStorage, {key, instrument}) do
      true ->
        instrument

      false ->
        [{^key, existing}] = :ets.lookup(Otel.Metrics.InstrumentsStorage, key)
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

  @overflow_attributes %{"otel.metric.overflow" => true}

  @spec maybe_overflow(
          instrument :: Otel.Metrics.Instrument.t(),
          agg_key :: term()
        ) :: term()
  defp maybe_overflow(instrument, {stream_name, _attrs} = agg_key) do
    if :ets.member(Otel.Metrics.MetricsStorage, agg_key) do
      agg_key
    else
      limit = instrument.cardinality_limit
      current = count_stream_keys(stream_name)

      if current >= limit do
        {stream_name, @overflow_attributes}
      else
        agg_key
      end
    end
  end

  @spec count_stream_keys(stream_name :: String.t()) :: non_neg_integer()
  defp count_stream_keys(stream_name) do
    :ets.foldl(
      fn entry, acc ->
        case elem(entry, 0) do
          {^stream_name, _} -> acc + 1
          _ -> acc
        end
      end,
      0,
      Otel.Metrics.MetricsStorage
    )
  end

  @spec offer_exemplar(
          instrument :: Otel.Metrics.Instrument.t(),
          agg_key :: term(),
          value :: number(),
          time :: non_neg_integer(),
          filtered_attrs :: map(),
          ctx :: Otel.Ctx.t()
        ) :: :ok
  defp offer_exemplar(instrument, agg_key, value, time, filtered_attrs, ctx) do
    reservoir = get_reservoir(instrument, agg_key)

    updated =
      Otel.Metrics.Exemplar.Reservoir.offer(reservoir, value, time, filtered_attrs, ctx)

    put_reservoir(agg_key, updated)
  end

  @spec get_reservoir(
          instrument :: Otel.Metrics.Instrument.t(),
          agg_key :: term()
        ) :: {module(), term()}
  defp get_reservoir(instrument, agg_key) do
    case :ets.lookup(Otel.Metrics.ExemplarsStorage, agg_key) do
      [{^agg_key, reservoir}] ->
        reservoir

      [] ->
        module = instrument.aggregation_module.exemplar_reservoir()
        opts = instrument.aggregation_module.exemplar_reservoir_opts(instrument)
        {module, module.new(opts)}
    end
  end

  @spec put_reservoir(agg_key :: term(), reservoir :: {module(), term()}) :: :ok
  defp put_reservoir(agg_key, reservoir) do
    :ets.insert(Otel.Metrics.ExemplarsStorage, {agg_key, reservoir})
    :ok
  end
end
