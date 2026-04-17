defmodule Otel.SDK.Trace.Sampler.AlwaysOn do
  @moduledoc """
  Sampler that always records and samples.

  Returns `RECORD_AND_SAMPLE` for every span.
  Description MUST be "AlwaysOnSampler" (L426).
  """

  @behaviour Otel.SDK.Trace.Sampler

  @spec setup(opts :: Otel.SDK.Trace.Sampler.opts()) :: Otel.SDK.Trace.Sampler.config()
  @impl true
  def setup(_opts), do: []

  @spec description(config :: Otel.SDK.Trace.Sampler.config()) ::
          Otel.SDK.Trace.Sampler.description()
  @impl true
  def description(_config), do: "AlwaysOnSampler"

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
  def should_sample(ctx, _trace_id, _links, _name, _kind, _attributes, _config) do
    tracestate =
      ctx
      |> Otel.API.Trace.current_span()
      |> Map.get(:tracestate, %Otel.API.Trace.TraceState{})

    {:record_and_sample, [], tracestate}
  end
end
