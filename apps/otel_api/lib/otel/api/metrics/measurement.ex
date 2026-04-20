defmodule Otel.API.Metrics.Measurement do
  @moduledoc """
  A single numeric measurement with attributes — spec: metrics/api.md
  (Measurement).

  A Measurement represents a data point reported via the metrics API to
  the SDK. Observable (asynchronous) instrument callbacks return a list
  of Measurements; each Measurement encapsulates a numeric value plus
  the attributes associated with it.

  Fields:

  - `value` — the numeric data point (`t:number/0`)
  - `attributes` — an `Otel.API.Attributes.t()` map associated
    with the measurement. Defaults to `%{}`.

  Synchronous instrument recording APIs (`Counter.add/4`, `Histogram.record/4`,
  etc.) take `(value, attributes)` as separate positional arguments and do
  not use this struct.
  """

  @type t :: %__MODULE__{
          value: number(),
          attributes: Otel.API.Attributes.t()
        }

  defstruct value: 0, attributes: %{}

  @doc """
  Creates a new Measurement.
  """
  @spec new(
          value :: number(),
          attributes :: Otel.API.Attributes.t()
        ) :: t()
  def new(value, attributes \\ %{}) do
    %__MODULE__{value: value, attributes: attributes}
  end
end
