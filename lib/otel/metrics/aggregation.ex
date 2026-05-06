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
  - Built-in implementations: `Otel.Metrics.Aggregation.{Sum,LastValue,ExplicitBucketHistogram}`
  """

  use Otel.Common.Types

  @typedoc """
  Per-stream-per-attribute-set aggregation key.

  Used as the ETS key in the metrics table to identify a single
  aggregation cell — combining the stream name and the
  attribute set the cell aggregates over. Constructed at every
  `aggregate/4` call site (e.g. `Otel.Metrics.Meter`) and at
  exemplar reservoir lookups.

  `InstrumentationScope` is not part of the key: minikube
  hardcodes a single scope (project memory
  `project_minikube_hardcode_decisions` § Follow-on #457), so
  threading it through every cell key would be redundant. Apps
  that share an instrument name across logical components
  namespace via the name itself (e.g. `phoenix.requests` /
  `ecto.requests`).
  """
  @type agg_key :: {
          name :: String.t(),
          attributes :: %{String.t() => primitive_any()}
        }

  @typedoc """
  Stream-level identity used by `collect/3` callbacks — the
  instrument's `name` (the prefix of `agg_key/0` minus
  attributes).
  """
  @type stream_key :: String.t()

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
