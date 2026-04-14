defmodule Otel.SDK.Metrics.Stream do
  @moduledoc """
  A metric stream produced by matching a View to an Instrument.

  Streams are the unit of metric output: each stream has a name,
  description, attribute filter, and references to its source
  instrument. Aggregation, exemplar reservoir, and cardinality
  limit fields are placeholders for subsequent Decisions.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          instrument: Otel.SDK.Metrics.Instrument.t(),
          attribute_keys: {:include, [atom()]} | {:exclude, [atom()]} | nil,
          aggregation: module() | nil,
          aggregation_options: map(),
          exemplar_reservoir: module() | nil,
          aggregation_cardinality_limit: pos_integer() | nil
        }

  defstruct name: "",
            description: "",
            instrument: %Otel.SDK.Metrics.Instrument{},
            attribute_keys: nil,
            aggregation: nil,
            aggregation_options: %{},
            exemplar_reservoir: nil,
            aggregation_cardinality_limit: nil

  @spec from_instrument(instrument :: Otel.SDK.Metrics.Instrument.t()) :: t()
  def from_instrument(instrument) do
    %__MODULE__{
      name: instrument.name,
      description: instrument.description,
      instrument: instrument,
      attribute_keys: advisory_attribute_keys(instrument)
    }
  end

  @spec from_view(
          view :: Otel.SDK.Metrics.View.t(),
          instrument :: Otel.SDK.Metrics.Instrument.t()
        ) :: t()
  def from_view(view, instrument) do
    config = view.config

    %__MODULE__{
      name: Otel.SDK.Metrics.View.stream_name(view, instrument),
      description: Otel.SDK.Metrics.View.stream_description(view, instrument),
      instrument: instrument,
      attribute_keys: Map.get(config, :attribute_keys, advisory_attribute_keys(instrument)),
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
      stream.aggregation || Otel.SDK.Metrics.Aggregation.default_module(stream.instrument.kind)

    aggregation_options =
      stream.aggregation_options
      |> merge_advisory_boundaries(stream.instrument)

    cardinality_limit = stream.aggregation_cardinality_limit || @default_cardinality_limit

    %{
      stream
      | aggregation: aggregation,
        aggregation_options: aggregation_options,
        aggregation_cardinality_limit: cardinality_limit
    }
  end

  @spec merge_advisory_boundaries(opts :: map(), instrument :: Otel.SDK.Metrics.Instrument.t()) ::
          map()
  defp merge_advisory_boundaries(opts, instrument) do
    case Keyword.get(instrument.advisory, :explicit_bucket_boundaries) do
      nil ->
        opts

      boundaries ->
        Map.put_new(opts, :boundaries, boundaries)
    end
  end

  @spec advisory_attribute_keys(instrument :: Otel.SDK.Metrics.Instrument.t()) ::
          {:include, [atom()]} | nil
  defp advisory_attribute_keys(instrument) do
    case Keyword.get(instrument.advisory, :attributes) do
      nil -> nil
      keys -> {:include, keys}
    end
  end
end
