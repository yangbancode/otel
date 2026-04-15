defmodule Otel.SDK.Metrics.Exemplar.Reservoir.SimpleFixedSize do
  @moduledoc """
  A reservoir that uses uniformly-weighted random sampling.

  Keeps at most `size` exemplars. Uses reservoir sampling algorithm:
  the Nth measurement has a `size/N` probability of being kept,
  replacing a random existing entry.
  """

  @behaviour Otel.SDK.Metrics.Exemplar.Reservoir

  @default_size 1

  @type state :: %{
          size: pos_integer(),
          count: non_neg_integer(),
          exemplars: %{non_neg_integer() => Otel.SDK.Metrics.Exemplar.t()}
        }

  @impl true
  @spec new(opts :: map()) :: state()
  def new(opts) do
    %{
      size: Map.get(opts, :size, @default_size),
      count: 0,
      exemplars: %{}
    }
  end

  @impl true
  @spec offer(
          state :: state(),
          value :: number(),
          time :: integer(),
          filtered_attributes :: map(),
          ctx :: Otel.API.Ctx.t()
        ) :: state()
  def offer(state, value, time, filtered_attributes, ctx) do
    exemplar = Otel.SDK.Metrics.Exemplar.new(value, time, filtered_attributes, ctx)
    count = state.count + 1

    exemplars =
      if count <= state.size do
        Map.put(state.exemplars, count - 1, exemplar)
      else
        idx = :rand.uniform(count) - 1

        if idx < state.size do
          Map.put(state.exemplars, idx, exemplar)
        else
          state.exemplars
        end
      end

    %{state | count: count, exemplars: exemplars}
  end

  @impl true
  @spec collect(state :: state()) :: {[Otel.SDK.Metrics.Exemplar.t()], state()}
  def collect(state) do
    exemplars = Map.values(state.exemplars)
    {exemplars, %{state | count: 0, exemplars: %{}}}
  end
end
