defmodule Otel.Metrics.Aggregation do
  @moduledoc """
  Aggregation behaviour and default instrument-to-aggregation
  mapping (`metrics/sdk.md` §Aggregation L612-L860).

  ## Public API

  | Callback | Role |
  |---|---|
  | `aggregate/4` | **SDK** (OTel API MUST) — record a measurement into an ETS-backed cell |
  | `collect/3` | **SDK** (OTel API MUST) — emit datapoints for the configured temporality |

  ## References

  - OTel Metrics SDK §Aggregation: `opentelemetry-specification/specification/metrics/sdk.md` L612-L860
  - Built-in implementations: `Otel.Metrics.Aggregation.{Drop,Sum,LastValue,ExplicitBucketHistogram}`
  """

  use Otel.Common.Types

  @typedoc """
  Per-stream-per-attribute-set aggregation key.

  Used as the ETS key in the metrics table to identify a single
  aggregation cell — combining stream identity (name + scope),
  the reader the aggregation belongs to, and the attribute set
  the cell aggregates over. Constructed at every `aggregate/4`
  call site (e.g. `Otel.Metrics.Meter`) and at exemplar
  reservoir lookups.
  """
  @type agg_key :: {
          name :: String.t(),
          scope :: Otel.InstrumentationScope.t(),
          reader_id :: reference() | nil,
          attributes :: %{String.t() => primitive_any()}
        }

  @typedoc """
  Stream-level identity used by `collect/3` callbacks — the
  `(name, scope)` prefix of `agg_key/0`, without the reader
  or attribute selection.
  """
  @type stream_key :: {name :: String.t(), scope :: Otel.InstrumentationScope.t()}

  @type datapoint :: %{
          attributes: %{String.t() => primitive_any()},
          value: term(),
          start_time: non_neg_integer(),
          time: non_neg_integer()
        }

  @callback aggregate(
              metrics_tab :: :ets.table(),
              key :: agg_key(),
              value :: number(),
              opts :: map()
            ) :: :ok

  @callback collect(
              metrics_tab :: :ets.table(),
              stream_key :: stream_key(),
              opts :: map()
            ) :: [datapoint()]

  @spec default_for(kind :: Otel.Metrics.Instrument.kind()) :: module()
  def default_for(:counter), do: Otel.Metrics.Aggregation.Sum
  def default_for(:updown_counter), do: Otel.Metrics.Aggregation.Sum
  def default_for(:histogram), do: Otel.Metrics.Aggregation.ExplicitBucketHistogram
  def default_for(:gauge), do: Otel.Metrics.Aggregation.LastValue
end
