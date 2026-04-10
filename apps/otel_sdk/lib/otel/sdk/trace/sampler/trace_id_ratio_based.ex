defmodule Otel.SDK.Trace.Sampler.TraceIdRatioBased do
  @moduledoc """
  Sampler that samples a configured ratio of traces.

  The sampling decision is deterministic based on trace_id (L462).
  A higher ratio always includes traces sampled by a lower ratio (L467).
  MUST ignore the parent SampledFlag (L447).
  """

  @behaviour Otel.SDK.Trace.Sampler

  # 2^63 - 1
  @max_value 9_223_372_036_854_775_807

  @impl true
  def setup(probability)
      when is_number(probability) and probability >= 0.0 and probability <= 1.0 do
    id_upper_bound =
      cond do
        probability == 0.0 -> 0
        probability == 1.0 -> @max_value
        true -> trunc(probability * @max_value)
      end

    %{probability: probability / 1.0, id_upper_bound: id_upper_bound}
  end

  @impl true
  def description(%{probability: probability}) do
    "TraceIdRatioBased{#{:erlang.float_to_binary(probability, decimals: 6)}}"
  end

  @impl true
  def should_sample(ctx, trace_id, _links, _name, _kind, _attributes, %{
        id_upper_bound: id_upper_bound
      }) do
    tracestate =
      ctx
      |> Otel.API.Trace.current_span()
      |> Map.get(:tracestate, %Otel.API.Trace.TraceState{})

    decision = decide(trace_id, id_upper_bound)
    {decision, %{}, tracestate}
  end

  defp decide(trace_id, _id_upper_bound) when trace_id == 0, do: :drop

  defp decide(trace_id, id_upper_bound) do
    lower_64_bits = Bitwise.band(trace_id, @max_value)

    if lower_64_bits < id_upper_bound do
      :record_and_sample
    else
      :drop
    end
  end
end
