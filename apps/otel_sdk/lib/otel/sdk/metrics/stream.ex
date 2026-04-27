defmodule Otel.SDK.Metrics.Stream do
  @moduledoc """
  A metric stream produced by matching a View to an Instrument.

  Streams are the unit of metric output: each stream has a name,
  description, attribute filter, and references to its source
  instrument. Aggregation, exemplar reservoir, and cardinality
  limit fields are populated by `resolve/1` from view config or
  spec defaults.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          instrument: Otel.API.Metrics.Instrument.t(),
          attribute_keys: {:include, [String.t()]} | {:exclude, [String.t()]} | nil,
          aggregation: module() | nil,
          aggregation_options: map(),
          exemplar_reservoir: module() | nil,
          aggregation_cardinality_limit: pos_integer() | nil,
          temporality: Otel.API.Metrics.Instrument.temporality(),
          reader_id: reference() | nil
        }

  defstruct name: "",
            description: "",
            instrument: %Otel.API.Metrics.Instrument{},
            attribute_keys: nil,
            aggregation: nil,
            aggregation_options: %{},
            exemplar_reservoir: nil,
            aggregation_cardinality_limit: nil,
            temporality: :cumulative,
            reader_id: nil

  @spec from_instrument(instrument :: Otel.API.Metrics.Instrument.t()) :: t()
  def from_instrument(instrument) do
    %__MODULE__{
      name: instrument.name,
      description: instrument.description,
      instrument: instrument
    }
  end

  @spec from_view(
          view :: Otel.SDK.Metrics.View.t(),
          instrument :: Otel.API.Metrics.Instrument.t()
        ) :: t()
  def from_view(view, instrument) do
    config = view.config

    %__MODULE__{
      name: Otel.SDK.Metrics.View.name(view, instrument),
      description: Otel.SDK.Metrics.View.description(view, instrument),
      instrument: instrument,
      attribute_keys: Map.get(config, :attribute_keys),
      aggregation: Map.get(config, :aggregation),
      aggregation_options: Map.get(config, :aggregation_options, %{}),
      exemplar_reservoir: Map.get(config, :exemplar_reservoir),
      aggregation_cardinality_limit: Map.get(config, :aggregation_cardinality_limit)
    }
  end

  @default_cardinality_limit 2000

  @spec resolve(stream :: t()) :: t()
  def resolve(%__MODULE__{} = stream) do
    aggregation =
      stream.aggregation || Otel.SDK.Metrics.Aggregation.default_for(stream.instrument.kind)

    aggregation_options =
      if stream.aggregation == nil do
        merge_advisory_boundaries(stream.aggregation_options, stream.instrument)
      else
        stream.aggregation_options
      end

    cardinality_limit = stream.aggregation_cardinality_limit || @default_cardinality_limit
    reservoir = stream.exemplar_reservoir || default_reservoir(aggregation, aggregation_options)

    %{
      stream
      | aggregation: aggregation,
        aggregation_options: aggregation_options,
        aggregation_cardinality_limit: cardinality_limit,
        exemplar_reservoir: reservoir
    }
  end

  @spec default_reservoir(aggregation :: module(), opts :: map()) :: module()
  defp default_reservoir(Otel.SDK.Metrics.Aggregation.ExplicitBucketHistogram, _opts) do
    Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket
  end

  defp default_reservoir(_aggregation, _opts) do
    Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize
  end

  @spec merge_advisory_boundaries(opts :: map(), instrument :: Otel.API.Metrics.Instrument.t()) ::
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
