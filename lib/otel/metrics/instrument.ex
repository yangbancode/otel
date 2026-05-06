defmodule Otel.Metrics.Instrument do
  @moduledoc """
  Instrument handle (OTel `metrics/api.md` §Instrument,
  Status: **Stable**, L178-L278).

  Carries the meter dispatcher plus all Instrument fields
  defined by the spec (`name`, `kind`, `unit`,
  `description`, `advisory`) plus `scope` (the
  `InstrumentationScope` the instrument was created
  under). Per spec L190-L191 the **identifying** fields
  are exactly `{name, kind, unit, description}`;
  `advisory` is a field on the Instrument but not part of
  the identity set, and `scope` is carried for downstream
  pipeline association rather than identity.

  The instrument is the handle users pass to recording
  functions (`Counter.add/3`, `Histogram.record/3`, etc.).

  ## Unified API + SDK struct

  A single struct shared by both API and SDK layers rather
  than an API-handle + SDK-record split. The `config` field
  captures the meter config (ETS table handles, scope,
  exemplar filter, reader configs) at creation time so the
  instrument is a self-sufficient handle; `record/3` and
  the callback path read from `instrument.config` without
  an auxiliary lookup. Resolution fields
  (`aggregation_module`, `aggregation_opts`,
  `cardinality_limit`, `exemplar_reservoir`) are filled at
  registration time from `:kind` and `:advisory` so the
  recording hot path needs no further lookup. Spec
  `metrics/api.md` L190-L191 treats Instrument as a single
  concept; erlang's reference implementation likewise
  defines one `#instrument{}` record shared across its API
  and SDK.

  The SDK stores the same struct in its `instruments_tab`
  ETS table. Stateless helpers that pure-pattern-match on
  `kind` or `name` (`downcased_name/1`, `monotonic?/1`)
  colocate here because they are pure data transformations
  with no runtime SDK coupling — matching the erlang
  reference, which places the same helpers on its
  API-layer `otel_instrument`.

  ## Divergences from opentelemetry-erlang

  `opentelemetry-erlang`'s `otel_instrument.erl` defines
  `is_monotonic(#instrument{kind=histogram}) -> true`; we
  return `false`. Our callsite is
  `Otel.Metrics.MetricExporter.collect/1`, which forwards
  the value to OTLP's `Sum.is_monotonic` field
  (`metrics.proto`). `is_monotonic` is a Sum-aggregation
  predicate; Histogram datapoints are not Sum datapoints,
  so the narrower definition matches that OTLP context.
  Erlang's wider reading is spec-ambiguous and not directly
  harmful in its own callsites, but would be wrong at ours.

  ## Public API

  | Function | Role |
  |---|---|
  | `downcased_name/1` | **SDK** (SDK helper) — case-insensitive comparison key (`sdk.md` L945-L958 MUST) |
  | `monotonic?/1` | **SDK** (SDK helper) — OTLP Sum `is_monotonic` for a given kind |

  All functions are safe for concurrent use.

  ## References

  - OTel Metrics API §Instrument: `opentelemetry-specification/specification/metrics/api.md` L178-L278
  - OTel Metrics API §Synchronous Instrument API: `opentelemetry-specification/specification/metrics/api.md` L302-L348
  - OTel Metrics API §Enabled (no required parameters): `opentelemetry-specification/specification/metrics/api.md` L485-L487
  - OTel Metrics SDK §Duplicate instrument registration: `opentelemetry-specification/specification/metrics/sdk.md` L904-L958
  - Reference impl: `opentelemetry-erlang/apps/opentelemetry_api_experimental/src/otel_instrument.erl`
  """

  use Otel.Common.Types

  @typedoc """
  Instrument kind. Enumerated per `metrics/api.md`
  §Synchronous instruments (L279-L300). Asynchronous
  (Observable) instrument kinds are intentionally absent
  — minikube delegates poll-based measurements to the
  BEAM-native `:telemetry` ecosystem (planned via a
  telemetry-handler bridge).
  """
  @type kind ::
          :counter
          | :histogram
          | :gauge
          | :updown_counter

  @typedoc """
  Aggregation temporality per `metrics/data-model.md`
  §Temporality (L400-L465).

  Minikube hardcodes `:cumulative` for every kind (matching
  the OTLP exporter default `TemporalityPreference::Cumulative`).
  The `:delta` member of the union remains so SDK consumers
  that read OTLP-derived `Sum.aggregation_temporality` can
  type-match the spec, but no aggregator emits delta
  datapoints internally.
  """
  @type temporality :: :cumulative | :delta

  @typedoc """
  Advisory parameters accepted by `Meter.create_*`, per
  `metrics/api.md` §Instrument advisory parameters
  (L245-L277).

  Spec-defined Stable keys:

  - `:explicit_bucket_boundaries` — `[number()]` sorted
    boundary list. Applies to `:histogram` (spec
    §ExplicitBucketBoundaries L260-L268, Status: Stable).

  Deferred (per the project's Stable-only policy):

  - `:attributes` — spec §Attributes L270-L277 is
    Status: Development.
  """
  @type advisory :: [
          {:explicit_bucket_boundaries, [number()]}
        ]

  @typedoc """
  Options accepted by `Meter.create_counter/3`,
  `create_histogram/3`, `create_gauge/3`, and
  `create_updown_counter/3`. Keys follow `metrics/api.md`
  §Synchronous Instrument API L302-L348.
  """
  @type create_opts :: [
          {:unit, String.t()}
          | {:description, String.t()}
          | {:advisory, advisory()}
        ]

  @typedoc """
  An Instrument struct (spec `metrics/api.md` §Instrument,
  L178-L198).

  Fields:

  - `config` — meter config snapshot captured at creation
    time (ETS table handles, scope, exemplar filter, reader
    configs). The recording path reads from this rather than
    from a separate Meter handle, so a custom config (test
    override) flows transparently into `record/3`.
  - `name` — spec §Instrument name syntax (L201-L218).
    Identifying.
  - `kind` — spec §Synchronous and Asynchronous
    instruments (L279-L300). Identifying.
  - `unit` — spec §Instrument unit (L220-L230).
    Identifying.
  - `description` — spec §Instrument description
    (L232-L243). Identifying.
  - `advisory` — spec §Instrument advisory parameters
    (L245-L277). **Not** part of identity.
  - `scope` — the `InstrumentationScope` the instrument
    was created under. **Not** part of identity; carried
    for downstream pipeline association.

  Per spec L190-L191 *"Instruments are identified by the
  `name`, `kind`, `unit`, and `description`"* —
  identifying fields are exactly those four.
  """
  @type t :: %__MODULE__{
          config: map(),
          name: String.t(),
          kind: kind(),
          unit: String.t(),
          description: String.t(),
          advisory: advisory(),
          scope: Otel.InstrumentationScope.t(),
          aggregation_module: module() | nil,
          aggregation_opts: map(),
          cardinality_limit: pos_integer() | nil,
          exemplar_reservoir: module() | nil
        }

  defstruct [
    :config,
    :name,
    :kind,
    :unit,
    :description,
    :advisory,
    :scope,
    :aggregation_module,
    :aggregation_opts,
    :cardinality_limit,
    :exemplar_reservoir
  ]

  @doc """
  **SDK** — Construct an Instrument. The `:kind` field is required;
  `:scope` defaults to the SDK identity, the rest fall back to
  proto3 zero values.

  Resolution fields (`aggregation_module`, `aggregation_opts`,
  `cardinality_limit`, `exemplar_reservoir`) are filled by
  `Otel.Metrics.Meter.register_instrument/4` from `:kind` and
  `:advisory`; constructing an Instrument directly leaves them
  `nil` / `%{}` and is only suitable as a "ghost instrument"
  for the unregistered-record no-op path.
  """
  @spec new(opts :: map()) :: t()
  def new(opts \\ %{}) do
    defaults = %{
      config: %{},
      name: "",
      kind: :counter,
      unit: "",
      description: "",
      advisory: [],
      scope: Otel.InstrumentationScope.new(),
      aggregation_module: nil,
      aggregation_opts: %{},
      cardinality_limit: nil,
      exemplar_reservoir: nil
    }

    struct!(__MODULE__, Map.merge(defaults, opts))
  end

  @doc """
  **SDK** (SDK helper) — case-insensitive comparison key.

  Returns the lowercased instrument name. Used by
  `Otel.Metrics.Meter` to key the ETS instruments and
  streams tables so spec `metrics/sdk.md` L945-L958 MUST
  is observed: *"The name of an Instrument is defined to
  be case-insensitive. If an SDK uses a case-sensitive
  encoding to represent this `name`, a duplicate
  instrument registration will occur when a user passes
  multiple casings of the same `name`."*
  """
  @spec downcased_name(name :: String.t()) :: String.t()
  def downcased_name(name), do: String.downcase(name)

  @doc """
  **SDK** (SDK helper) — whether the given instrument
  `kind`'s Sum aggregation is monotonic.

  Maps to OTLP's `Sum.is_monotonic` field
  (`opentelemetry-proto` `metrics.proto`). Only Counter
  aggregates as a monotonic Sum; other kinds either do not
  aggregate as Sum at all (Histogram, Gauge) or allow
  decrements (UpDownCounter).

  See `## Divergences from opentelemetry-erlang` in the
  module docs for why this is narrower than erlang's
  `is_monotonic`.
  """
  @spec monotonic?(kind :: kind()) :: boolean()
  def monotonic?(:counter), do: true
  def monotonic?(_kind), do: false
end
