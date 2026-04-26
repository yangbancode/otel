defmodule Otel.SDK.Metrics.Exemplar.Reservoir.AlignedHistogramBucket do
  @moduledoc """
  A reservoir aligned with explicit histogram bucket boundaries.

  Stores at most one exemplar per bucket. When a new measurement
  falls into a bucket that already has an exemplar, the existing
  one is replaced.
  """

  @behaviour Otel.SDK.Metrics.Exemplar.Reservoir

  use Otel.API.Common.Types

  @type state :: %{
          boundaries: [number()],
          exemplars: %{non_neg_integer() => Otel.SDK.Metrics.Exemplar.t()}
        }

  @impl true
  @spec new(opts :: map()) :: state()
  def new(opts) do
    %{
      boundaries: Map.get(opts, :boundaries, []),
      exemplars: %{}
    }
  end

  @impl true
  @spec offer(
          state :: state(),
          value :: number(),
          time :: non_neg_integer(),
          filtered_attributes :: %{String.t() => primitive_any()},
          ctx :: Otel.API.Ctx.t()
        ) :: state()
  def offer(state, value, time, filtered_attributes, ctx) do
    exemplar = Otel.SDK.Metrics.Exemplar.new(value, time, filtered_attributes, ctx)
    bucket_idx = find_bucket(value, state.boundaries)
    %{state | exemplars: Map.put(state.exemplars, bucket_idx, exemplar)}
  end

  @impl true
  @spec collect(state :: state()) :: {[Otel.SDK.Metrics.Exemplar.t()], state()}
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
