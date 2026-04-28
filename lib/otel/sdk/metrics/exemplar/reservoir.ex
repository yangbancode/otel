defmodule Otel.SDK.Metrics.Exemplar.Reservoir do
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

  use Otel.API.Common.Types

  @callback new(opts :: map()) :: state :: term()

  @callback offer(
              state :: term(),
              value :: number(),
              time :: non_neg_integer(),
              filtered_attributes :: %{String.t() => primitive_any()},
              ctx :: Otel.API.Ctx.t()
            ) :: state :: term()

  @callback collect(state :: term()) :: {[Otel.SDK.Metrics.Exemplar.t()], state :: term()}

  @spec offer(
          reservoir :: {module(), term()} | nil,
          filter :: Otel.SDK.Metrics.Exemplar.Filter.t(),
          value :: number(),
          time :: non_neg_integer(),
          filtered_attributes :: %{String.t() => primitive_any()},
          ctx :: Otel.API.Ctx.t()
        ) :: {module(), term()} | nil
  def offer(nil, _filter, _value, _time, _attrs, _ctx), do: nil

  def offer({module, state}, filter, value, time, filtered_attributes, ctx) do
    if Otel.SDK.Metrics.Exemplar.Filter.should_sample?(filter, ctx) do
      {module, module.offer(state, value, time, filtered_attributes, ctx)}
    else
      {module, state}
    end
  end

  @spec collect(reservoir :: {module(), term()} | nil) ::
          {[Otel.SDK.Metrics.Exemplar.t()], {module(), term()} | nil}
  def collect(nil), do: {[], nil}

  def collect({module, state}) do
    {exemplars, new_state} = module.collect(state)
    {exemplars, {module, new_state}}
  end
end
