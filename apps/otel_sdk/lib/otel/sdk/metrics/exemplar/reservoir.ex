defmodule Otel.SDK.Metrics.Exemplar.Reservoir do
  @moduledoc """
  ExemplarReservoir behaviour. A reservoir samples and stores
  exemplars from offered measurements, then returns them during
  collection.

  Each reservoir instance is associated with a single timeseries
  (stream + attribute combination).
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

  @spec offer_to(
          reservoir :: {module(), term()} | nil,
          filter :: Otel.SDK.Metrics.Exemplar.Filter.t(),
          value :: number(),
          time :: non_neg_integer(),
          filtered_attributes :: %{String.t() => primitive_any()},
          ctx :: Otel.API.Ctx.t()
        ) :: {module(), term()} | nil
  def offer_to(nil, _filter, _value, _time, _attrs, _ctx), do: nil

  def offer_to({module, state}, filter, value, time, filtered_attributes, ctx) do
    if Otel.SDK.Metrics.Exemplar.Filter.should_sample?(filter, ctx) do
      {module, module.offer(state, value, time, filtered_attributes, ctx)}
    else
      {module, state}
    end
  end

  @spec collect_from(reservoir :: {module(), term()} | nil) ::
          {[Otel.SDK.Metrics.Exemplar.t()], {module(), term()} | nil}
  def collect_from(nil), do: {[], nil}

  def collect_from({module, state}) do
    {exemplars, new_state} = module.collect(state)
    {exemplars, {module, new_state}}
  end
end
