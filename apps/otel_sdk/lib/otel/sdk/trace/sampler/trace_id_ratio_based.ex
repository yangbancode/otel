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

  @spec setup(opts :: Otel.SDK.Trace.Sampler.opts()) :: Otel.SDK.Trace.Sampler.config()
  @impl true
  def setup(probability)
      when is_float(probability) and probability >= 0.0 and probability <= 1.0 do
    id_upper_bound =
      cond do
        probability == 0.0 -> 0
        probability == 1.0 -> @max_value
        true -> trunc(probability * @max_value)
      end

    %{probability: probability, id_upper_bound: id_upper_bound}
  end

  @spec description(config :: Otel.SDK.Trace.Sampler.config()) ::
          Otel.SDK.Trace.Sampler.description()
  @impl true
  def description(%{probability: probability}) do
    "TraceIdRatioBased{#{:erlang.float_to_binary(probability, decimals: 6)}}"
  end

  @spec should_sample(
          ctx :: Otel.API.Ctx.t(),
          trace_id :: Otel.API.Trace.TraceId.t(),
          links :: [{Otel.API.Trace.SpanContext.t(), [Otel.API.Common.Attribute.t()]}],
          name :: String.t(),
          kind :: Otel.API.Trace.SpanKind.t(),
          attributes :: [Otel.API.Common.Attribute.t()],
          config :: Otel.SDK.Trace.Sampler.config()
        ) :: Otel.SDK.Trace.Sampler.sampling_result()
  @impl true
  def should_sample(ctx, trace_id, _links, _name, _kind, _attributes, %{
        id_upper_bound: id_upper_bound
      }) do
    tracestate =
      ctx
      |> Otel.API.Trace.current_span()
      |> Map.get(:tracestate, %Otel.API.Trace.TraceState{})

    decision = decide(trace_id, id_upper_bound)
    {decision, [], tracestate}
  end

  @spec decide(trace_id :: Otel.API.Trace.TraceId.t(), id_upper_bound :: non_neg_integer()) ::
          :record_and_sample | :drop
  defp decide(%Otel.API.Trace.TraceId{bytes: <<0::128>>}, _id_upper_bound), do: :drop

  defp decide(
         %Otel.API.Trace.TraceId{bytes: <<_::64, lower_64::unsigned-integer-64>>},
         id_upper_bound
       ) do
    if Bitwise.band(lower_64, @max_value) < id_upper_bound do
      :record_and_sample
    else
      :drop
    end
  end
end
