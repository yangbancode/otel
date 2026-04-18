defmodule Otel.API.Metrics.Instrument do
  @moduledoc """
  Instrument handle returned by `Meter.create_*` functions.

  Carries the meter dispatcher plus all identifying fields defined by
  the OpenTelemetry spec (name, kind, unit, description, advisory,
  scope). The instrument is the handle users pass to recording
  functions such as `Counter.add/3`, `Histogram.record/3`, etc.

  The SDK stores the same struct in its instruments ETS table, and
  extends it with advisory validation / temporality mapping / duplicate
  detection helpers defined here. These helpers are pure functions and
  have no runtime coupling to SDK state — colocating them with the
  struct keeps "one entity = one module".

  All functions are safe for concurrent use.
  """

  require Logger

  @type kind ::
          :counter
          | :histogram
          | :gauge
          | :updown_counter
          | :observable_counter
          | :observable_gauge
          | :observable_updown_counter

  @type temporality :: :cumulative | :delta

  @typedoc """
  Advisory parameters accepted by `Meter.create_*` and by `validate_advisory/2`.

  Keys defined by the OpenTelemetry spec:
  - `:explicit_bucket_boundaries` — sorted list of boundary numbers.
    Only valid for `:histogram`; ignored with a warning for other kinds.
  - `:attributes` — list of attribute keys to retain. The SDK applies
    this as a view-less attribute filter.
  """
  @type advisory_opt ::
          {:explicit_bucket_boundaries, [number()]}
          | {:attributes, [String.t()]}

  @type advisory :: [advisory_opt()]

  @typedoc """
  Options accepted by `Meter.create_counter/3`, `create_histogram/3`,
  `create_gauge/3`, `create_updown_counter/3`, and the three observable
  `create_*/3` variants. Keys follow the OpenTelemetry Metrics API spec.
  """
  @type create_opt ::
          {:unit, String.t()}
          | {:description, String.t()}
          | {:advisory, advisory()}

  @type create_opts :: [create_opt()]

  @typedoc """
  Options accepted by per-instrument `enabled?/2` and by `Meter.enabled?/2`.

  Spec-defined keys (MAY-support; SDKs may ignore):
  - `:context` — evaluation context
  - `:attributes` — attributes that would be recorded with the measurement
  """
  @type enabled_opt ::
          {:context, Otel.API.Ctx.t()}
          | {:attributes, Otel.API.Attribute.attributes()}

  @type enabled_opts :: [enabled_opt()]

  @typedoc """
  Options accepted by `Meter.register_callback/5`.

  The spec does not define specific keys; kept as a keyword list for
  SDK-specific extensions.
  """
  @type register_callback_opts :: keyword()

  @type t :: %__MODULE__{
          meter: Otel.API.Metrics.Meter.t() | nil,
          name: String.t(),
          kind: kind(),
          unit: String.t(),
          description: String.t(),
          advisory: advisory(),
          scope: Otel.API.InstrumentationScope.t()
        }

  defstruct meter: nil,
            name: "",
            kind: :counter,
            unit: "",
            description: "",
            advisory: [],
            scope: %Otel.API.InstrumentationScope{}

  @name_regex ~r/^[A-Za-z][A-Za-z0-9_.\-\/]{0,254}$/

  @doc """
  Validates instrument name against the OTel ABNF syntax.

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
  Returns the conflict type between two instruments that share the same
  downcased name but differ in identifying fields.

  - `:description_only` — only description differs
  - `:distinguishable` — kind differs (resolvable by renaming View)
  - `:unresolvable` — unit or other fields differ
  """
  @spec conflict_type(instrument_a :: t(), instrument_b :: t()) ::
          :description_only | :distinguishable | :unresolvable
  def conflict_type(a, b) do
    cond do
      a.kind == b.kind and a.unit == b.unit and a.description != b.description ->
        :description_only

      a.kind != b.kind ->
        :distinguishable

      true ->
        :unresolvable
    end
  end

  @doc """
  Validates advisory parameters for the given instrument kind.

  Returns validated advisory keyword list. Invalid params are dropped
  with a logger warning.
  """
  @spec validate_advisory(kind :: kind(), advisory :: advisory()) :: advisory()
  def validate_advisory(kind, advisory) do
    Enum.flat_map(advisory, fn param -> validate_advisory_param(kind, param) end)
  end

  @spec validate_advisory_param(kind :: kind(), param :: advisory_opt() | {atom(), term()}) ::
          advisory()
  defp validate_advisory_param(:histogram, {:explicit_bucket_boundaries, boundaries})
       when is_list(boundaries) do
    if sorted?(boundaries) do
      [explicit_bucket_boundaries: boundaries]
    else
      Logger.warning(
        "advisory explicit_bucket_boundaries must be a sorted list of numbers, ignoring"
      )

      []
    end
  end

  defp validate_advisory_param(_kind, {:explicit_bucket_boundaries, _boundaries}) do
    Logger.warning("advisory explicit_bucket_boundaries is only valid for histogram, ignoring")
    []
  end

  defp validate_advisory_param(_kind, {:attributes, keys}) when is_list(keys) do
    [attributes: keys]
  end

  defp validate_advisory_param(_kind, {key, _value}) do
    Logger.warning("unknown advisory parameter #{inspect(key)}, ignoring")
    []
  end

  @spec temporality(kind :: kind()) :: temporality()
  def temporality(:counter), do: :delta
  def temporality(:updown_counter), do: :delta
  def temporality(:histogram), do: :delta
  def temporality(:gauge), do: :cumulative
  def temporality(:observable_counter), do: :cumulative
  def temporality(:observable_gauge), do: :cumulative
  def temporality(:observable_updown_counter), do: :cumulative

  @spec default_temporality_mapping() :: %{kind() => temporality()}
  def default_temporality_mapping do
    %{
      counter: :cumulative,
      updown_counter: :cumulative,
      histogram: :cumulative,
      gauge: :cumulative,
      observable_counter: :cumulative,
      observable_gauge: :cumulative,
      observable_updown_counter: :cumulative
    }
  end

  @spec monotonic?(kind :: kind()) :: boolean()
  def monotonic?(:counter), do: true
  def monotonic?(:observable_counter), do: true
  def monotonic?(_kind), do: false

  @spec sorted?(list :: [number()]) :: boolean()
  defp sorted?([]), do: true
  defp sorted?([_]), do: true
  defp sorted?([a, b | rest]), do: a < b and sorted?([b | rest])
end
