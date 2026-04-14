defmodule Otel.SDK.Metrics.Instrument do
  @moduledoc """
  SDK instrument record stored in ETS.

  Holds instrument identity (name, kind, unit, description) and
  advisory parameters. Instruments are keyed by `{scope, downcased_name}`
  in ETS for case-insensitive duplicate detection.
  """

  @type kind ::
          :counter
          | :histogram
          | :gauge
          | :updown_counter
          | :observable_counter
          | :observable_gauge
          | :observable_updown_counter

  @type t :: %__MODULE__{
          name: String.t(),
          kind: kind(),
          unit: String.t(),
          description: String.t(),
          advisory: keyword(),
          scope: Otel.API.InstrumentationScope.t()
        }

  defstruct name: "",
            kind: :counter,
            unit: "",
            description: "",
            advisory: [],
            scope: %Otel.API.InstrumentationScope{}

  @name_regex ~r/^[A-Za-z][A-Za-z0-9_.\-\/]{0,254}$/

  @doc """
  Validates instrument name against the ABNF syntax.

  Returns `{:ok, name}` if valid, `{:error, reason}` if invalid.
  """
  @spec validate_name(name :: String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def validate_name(nil), do: {:error, "instrument name must not be nil"}
  def validate_name(""), do: {:error, "instrument name must not be empty"}

  def validate_name(name) when is_binary(name) do
    if Regex.match?(@name_regex, name) do
      {:ok, name}
    else
      {:error, "instrument name #{inspect(name)} does not conform to syntax"}
    end
  end

  @doc """
  Returns the downcased name for case-insensitive comparison.
  """
  @spec downcased_name(name :: String.t()) :: String.t()
  def downcased_name(name), do: String.downcase(name)

  @doc """
  Checks if two instruments are identical (all identifying fields equal).
  """
  @spec identical?(instrument_a :: t(), instrument_b :: t()) :: boolean()
  def identical?(a, b) do
    downcased_name(a.name) == downcased_name(b.name) and
      a.kind == b.kind and
      a.unit == b.unit and
      a.description == b.description
  end

  @doc """
  Validates advisory parameters for the given instrument kind.

  Returns validated advisory keyword list. Invalid params are dropped
  with a logger warning.
  """
  @spec validate_advisory(kind :: kind(), advisory :: keyword()) :: keyword()
  def validate_advisory(kind, advisory) do
    Enum.flat_map(advisory, fn param -> validate_advisory_param(kind, param) end)
  end

  @spec validate_advisory_param(kind :: kind(), param :: {atom(), term()}) :: keyword()
  defp validate_advisory_param(:histogram, {:explicit_bucket_boundaries, boundaries})
       when is_list(boundaries) do
    if sorted?(boundaries) do
      [explicit_bucket_boundaries: boundaries]
    else
      :logger.warning(
        "advisory explicit_bucket_boundaries must be a sorted list of numbers, ignoring",
        %{domain: [:otel, :metrics]}
      )

      []
    end
  end

  defp validate_advisory_param(_kind, {:explicit_bucket_boundaries, _boundaries}) do
    :logger.warning(
      "advisory explicit_bucket_boundaries is only valid for histogram, ignoring",
      %{domain: [:otel, :metrics]}
    )

    []
  end

  defp validate_advisory_param(_kind, {key, _value}) do
    :logger.warning(
      "unknown advisory parameter #{inspect(key)}, ignoring",
      %{domain: [:otel, :metrics]}
    )

    []
  end

  @spec sorted?(list :: [number()]) :: boolean()
  defp sorted?([]), do: true
  defp sorted?([_]), do: true
  defp sorted?([a, b | rest]), do: a < b and sorted?([b | rest])
end
