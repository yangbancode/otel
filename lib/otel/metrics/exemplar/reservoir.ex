defmodule Otel.Metrics.Exemplar.Reservoir do
  @moduledoc """
  ExemplarReservoir behaviour. A reservoir samples and stores
  exemplars from offered measurements, then returns them during
  collection.

  Each reservoir instance is associated with a single timeseries
  (stream + attribute combination).

  ## Concurrency

  Spec `metrics/sdk.md` L1878 (Status: Stable) — *"all methods
  MUST be safe to be called concurrently."* Implementing
  modules MUST be safe for concurrent invocation of `offer/5`
  and `collect/1`. Built-in implementations
  (`SimpleFixedSize`, `AlignedHistogramBucket`) satisfy this
  via `:counters` / `:atomics` / `:ets` with appropriate
  concurrency options.
  """

  use Otel.Common.Types

  @callback new(opts :: map()) :: state :: term()

  @callback offer(
              state :: term(),
              value :: number(),
              time :: non_neg_integer(),
              filtered_attributes :: %{String.t() => primitive_any()},
              ctx :: Otel.Ctx.t()
            ) :: state :: term()

  @callback collect(state :: term()) :: {[Otel.Metrics.Exemplar.t()], state :: term()}

  @spec offer(
          reservoir :: {module(), term()},
          value :: number(),
          time :: non_neg_integer(),
          filtered_attributes :: %{String.t() => primitive_any()},
          ctx :: Otel.Ctx.t()
        ) :: {module(), term()}
  def offer({module, state}, value, time, filtered_attributes, ctx) do
    if Otel.Metrics.Exemplar.Filter.should_sample?(ctx) do
      {module, module.offer(state, value, time, filtered_attributes, ctx)}
    else
      {module, state}
    end
  end

  @spec collect(reservoir :: {module(), term()}) ::
          {[Otel.Metrics.Exemplar.t()], {module(), term()}}
  def collect({module, state}) do
    {exemplars, new_state} = module.collect(state)
    {exemplars, {module, new_state}}
  end
end
