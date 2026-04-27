defmodule Otel.SDK.Metrics.View do
  @moduledoc """
  Defines instrument selection criteria and stream configuration.

  A View maps matching instruments to metric streams by specifying
  which instruments to select and how the resulting stream should
  be configured (name override, description override, attribute
  filtering, aggregation, etc.).

  All selection criteria are optional and additive (AND). An
  instrument must match all provided criteria for the View to apply.
  """

  use Otel.API.Common.Types

  @type criteria :: %{
          optional(:name) => String.t(),
          optional(:type) => Otel.API.Metrics.Instrument.kind(),
          optional(:unit) => String.t(),
          optional(:meter_name) => String.t(),
          optional(:meter_version) => String.t(),
          optional(:meter_schema_url) => String.t()
        }

  @type config :: %{
          optional(:name) => String.t(),
          optional(:description) => String.t(),
          optional(:attribute_keys) => {:include, [String.t()]} | {:exclude, [String.t()]},
          optional(:aggregation) => module(),
          optional(:aggregation_options) => map(),
          optional(:exemplar_reservoir) => module(),
          optional(:aggregation_cardinality_limit) => pos_integer()
        }

  @type t :: %__MODULE__{
          criteria: criteria(),
          config: config()
        }

  defstruct criteria: %{},
            config: %{}

  @spec new(criteria :: criteria(), config :: config()) ::
          {:ok, t()} | {:error, String.t()}
  def new(criteria \\ %{}, config \\ %{}) do
    with :ok <- validate_wildcard_name(criteria, config) do
      {:ok, %__MODULE__{criteria: criteria, config: config}}
    end
  end

  @spec matches?(view :: t(), instrument :: Otel.API.Metrics.Instrument.t()) :: boolean()
  def matches?(%__MODULE__{criteria: criteria}, instrument) do
    Enum.all?(criteria, fn {key, value} -> matches_criterion?(key, value, instrument) end)
  end

  @spec stream_name(view :: t(), instrument :: Otel.API.Metrics.Instrument.t()) :: String.t()
  def stream_name(%__MODULE__{config: config}, instrument) do
    Map.get(config, :name, instrument.name)
  end

  @spec stream_description(view :: t(), instrument :: Otel.API.Metrics.Instrument.t()) ::
          String.t()
  def stream_description(%__MODULE__{config: config}, instrument) do
    Map.get(config, :description, instrument.description)
  end

  @spec validate_wildcard_name(criteria :: criteria(), config :: config()) ::
          :ok | {:error, String.t()}
  defp validate_wildcard_name(criteria, config) do
    if Map.get(criteria, :name) == "*" and Map.has_key?(config, :name) do
      {:error, "wildcard view must not specify a stream name"}
    else
      :ok
    end
  end

  @spec matches_criterion?(
          key :: atom(),
          value :: term(),
          instrument :: Otel.API.Metrics.Instrument.t()
        ) :: boolean()
  defp matches_criterion?(:name, "*", _instrument), do: true

  # Spec `metrics/sdk.md` L276-L277 *"If the value of name is
  # exactly the same as an Instrument, then the criterion
  # matches that instrument."* — combined with L947 *"The name
  # of an Instrument is defined to be case-insensitive"*,
  # "exactly the same" resolves to case-insensitive equality.
  defp matches_criterion?(:name, name, instrument) do
    String.downcase(name) == String.downcase(instrument.name)
  end

  defp matches_criterion?(:type, type, instrument) do
    type == instrument.kind
  end

  defp matches_criterion?(:unit, unit, instrument) do
    unit == instrument.unit
  end

  defp matches_criterion?(:meter_name, meter_name, instrument) do
    meter_name == instrument.scope.name
  end

  defp matches_criterion?(:meter_version, meter_version, instrument) do
    meter_version == instrument.scope.version
  end

  defp matches_criterion?(:meter_schema_url, schema_url, instrument) do
    schema_url == instrument.scope.schema_url
  end

  defp matches_criterion?(_key, _value, _instrument), do: true
end
