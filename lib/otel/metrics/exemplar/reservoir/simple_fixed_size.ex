defmodule Otel.Metrics.Exemplar.Reservoir.SimpleFixedSize do
  @moduledoc """
  A reservoir that uses uniformly-weighted random sampling.

  Keeps at most `size` exemplars. Uses reservoir sampling algorithm:
  the Nth measurement has a `size/N` probability of being kept,
  replacing a random existing entry.
  """

  use Otel.Common.Types

  @default_size 1

  @type state :: %{
          size: pos_integer(),
          count: non_neg_integer(),
          exemplars: %{non_neg_integer() => Otel.Metrics.Exemplar.t()}
        }

  @spec new(opts :: map()) :: state()
  def new(opts \\ %{}) do
    %{
      size: Map.get(opts, :size, @default_size),
      count: 0,
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
    {trace_id, span_id} = Otel.Metrics.Exemplar.trace_info(ctx)

    exemplar =
      Otel.Metrics.Exemplar.new(%{
        value: value,
        time: time,
        filtered_attributes: filtered_attributes,
        trace_id: trace_id,
        span_id: span_id
      })

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

  @spec collect(state :: state()) :: {[Otel.Metrics.Exemplar.t()], state()}
  def collect(state) do
    exemplars = Map.values(state.exemplars)
    {exemplars, %{state | count: 0, exemplars: %{}}}
  end
end
