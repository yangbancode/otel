defmodule Otel.Metrics.Stream do
  @moduledoc """
  A metric stream produced from an Instrument.

  Streams are the unit of metric output: each stream has a name,
  description, and reference to its source instrument. Aggregation,
  exemplar reservoir, and cardinality limit fields are populated
  by `resolve/1` from spec defaults (and the instrument's advisory
  parameters where applicable).
  """

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          instrument: Otel.Metrics.Instrument.t(),
          aggregation: module() | nil,
          aggregation_options: map(),
          exemplar_reservoir: module() | nil,
          aggregation_cardinality_limit: pos_integer() | nil,
          temporality: Otel.Metrics.Instrument.temporality()
        }

  defstruct name: "",
            description: "",
            instrument: %Otel.Metrics.Instrument{},
            aggregation: nil,
            aggregation_options: %{},
            exemplar_reservoir: nil,
            aggregation_cardinality_limit: nil,
            temporality: :cumulative

  @spec from_instrument(instrument :: Otel.Metrics.Instrument.t()) :: t()
  def from_instrument(instrument) do
    %__MODULE__{
      name: instrument.name,
      description: instrument.description,
      instrument: instrument
    }
  end

  @default_cardinality_limit 2000

  @spec resolve(stream :: t()) :: t()
  def resolve(%__MODULE__{} = stream) do
    aggregation = Otel.Metrics.Aggregation.default_for(stream.instrument.kind)
    aggregation_options = merge_advisory_boundaries(%{}, stream.instrument)
    reservoir = default_reservoir(aggregation, aggregation_options)

    %{
      stream
      | aggregation: aggregation,
        aggregation_options: aggregation_options,
        aggregation_cardinality_limit: @default_cardinality_limit,
        exemplar_reservoir: reservoir
    }
  end

  @spec default_reservoir(aggregation :: module(), opts :: map()) :: module()
  defp default_reservoir(Otel.Metrics.Aggregation.ExplicitBucketHistogram, _opts) do
    Otel.Metrics.Exemplar.Reservoir.AlignedHistogramBucket
  end

  defp default_reservoir(_aggregation, _opts) do
    Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize
  end

  @spec merge_advisory_boundaries(opts :: map(), instrument :: Otel.Metrics.Instrument.t()) ::
          map()
  defp merge_advisory_boundaries(opts, instrument) do
    case Keyword.get(instrument.advisory, :explicit_bucket_boundaries) do
      nil ->
        opts

      boundaries ->
        Map.put_new(opts, :boundaries, boundaries)
    end
  end
end
