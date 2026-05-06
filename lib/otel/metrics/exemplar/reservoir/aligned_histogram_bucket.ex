defmodule Otel.Metrics.Exemplar.Reservoir.AlignedHistogramBucket do
  @moduledoc """
  A reservoir aligned with explicit histogram bucket boundaries.

  Stores at most one exemplar per bucket. When a new measurement
  falls into a bucket that already has an exemplar, the existing
  one is replaced.

  ## Spec compliance

  Spec `metrics/sdk.md` L1248-L1252 — *"This implementation
  MUST store at most one measurement that falls within a
  histogram bucket, and SHOULD use a uniformly-weighted
  sampling algorithm based on the number of measurements the
  bucket has seen so far ... Alternatively, the implementation
  MAY instead keep the last seen measurement that falls within
  a histogram bucket."*

  We implement the **MAY alternative** (keep last-seen) — the
  simpler of the two paths the spec offers. The MUST about at
  most one exemplar per bucket is satisfied by the
  `%{bucket_index => exemplar}` map shape.
  """

  use Otel.Common.Types

  @type state :: %{
          boundaries: [number()],
          exemplars: %{non_neg_integer() => Otel.Metrics.Exemplar.t()}
        }

  @spec new(opts :: map()) :: state()
  def new(opts) do
    %{
      boundaries: Map.get(opts, :boundaries, []),
      exemplars: %{}
    }
  end

  @spec offer(
          state :: state(),
          value :: number(),
          time :: non_neg_integer(),
          filtered_attributes :: %{String.t() => primitive_any()},
          ctx :: Otel.Ctx.t()
        ) :: state()
  def offer(state, value, time, filtered_attributes, ctx) do
    exemplar =
      Otel.Metrics.Exemplar.new(%{
        value: value,
        time: time,
        filtered_attributes: filtered_attributes,
        ctx: ctx
      })
    bucket_idx = find_bucket(value, state.boundaries)
    %{state | exemplars: Map.put(state.exemplars, bucket_idx, exemplar)}
  end

  @spec collect(state :: state()) :: {[Otel.Metrics.Exemplar.t()], state()}
  def collect(state) do
    exemplars = Map.values(state.exemplars)
    {exemplars, %{state | exemplars: %{}}}
  end

  @spec find_bucket(value :: number(), boundaries :: [number()]) :: non_neg_integer()
  defp find_bucket(value, boundaries), do: find_bucket(value, boundaries, 0)

  @spec find_bucket(value :: number(), boundaries :: [number()], index :: non_neg_integer()) ::
          non_neg_integer()
  defp find_bucket(_value, [], index), do: index

  defp find_bucket(value, [boundary | rest], index) do
    if value <= boundary, do: index, else: find_bucket(value, rest, index + 1)
  end
end
