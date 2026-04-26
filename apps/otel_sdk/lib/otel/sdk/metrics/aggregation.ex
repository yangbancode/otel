defmodule Otel.SDK.Metrics.Aggregation do
  @moduledoc """
  Aggregation behaviour and default instrument-to-aggregation mapping.
  """

  use Otel.API.Common.Types

  @typedoc """
  Per-stream-per-attribute-set aggregation key.

  Used as the ETS key in the metrics table to identify a single
  aggregation cell — combining stream identity (name + scope),
  the reader the aggregation belongs to, and the attribute set
  the cell aggregates over. Constructed at every `aggregate/4`
  call site (e.g. `Otel.SDK.Metrics.Meter`) and at exemplar
  reservoir lookups.
  """
  @type agg_key :: {
          name :: String.t(),
          scope :: Otel.API.InstrumentationScope.t(),
          reader_id :: reference() | nil,
          attributes :: %{String.t() => primitive() | [primitive()]}
        }

  @typedoc """
  Stream-level identity used by `collect/3` callbacks — the
  `(name, scope)` prefix of `agg_key/0`, without the reader
  or attribute selection.
  """
  @type stream_key :: {name :: String.t(), scope :: Otel.API.InstrumentationScope.t()}

  @type datapoint :: %{
          attributes: %{String.t() => primitive() | [primitive()]},
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

  @spec default_module(kind :: Otel.API.Metrics.Instrument.kind()) :: module()
  def default_module(:counter), do: Otel.SDK.Metrics.Aggregation.Sum
  def default_module(:updown_counter), do: Otel.SDK.Metrics.Aggregation.Sum
  def default_module(:histogram), do: Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram
  def default_module(:gauge), do: Otel.SDK.Metrics.Aggregation.LastValue
  def default_module(:observable_counter), do: Otel.SDK.Metrics.Aggregation.Sum
  def default_module(:observable_gauge), do: Otel.SDK.Metrics.Aggregation.LastValue
  def default_module(:observable_updown_counter), do: Otel.SDK.Metrics.Aggregation.Sum
end
