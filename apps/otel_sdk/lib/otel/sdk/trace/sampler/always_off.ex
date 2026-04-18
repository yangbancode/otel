defmodule Otel.SDK.Trace.Sampler.AlwaysOff do
  @moduledoc """
  Sampler that always drops.

  Returns `DROP` for every span.
  Description MUST be "AlwaysOffSampler" (L431).
  """

  @behaviour Otel.SDK.Trace.Sampler

  @spec setup(opts :: Otel.SDK.Trace.Sampler.opts()) :: Otel.SDK.Trace.Sampler.config()
  @impl true
  def setup(_opts), do: []

  @spec description(config :: Otel.SDK.Trace.Sampler.config()) ::
          Otel.SDK.Trace.Sampler.description()
  @impl true
  def description(_config), do: "AlwaysOffSampler"

  @spec should_sample(
          ctx :: Otel.API.Ctx.t(),
          trace_id :: Otel.API.Trace.TraceId.t(),
          links :: [{Otel.API.Trace.SpanContext.t(), map()}],
          name :: String.t(),
          kind :: Otel.API.Trace.SpanKind.t(),
          attributes :: map(),
          config :: Otel.SDK.Trace.Sampler.config()
        ) :: Otel.SDK.Trace.Sampler.sampling_result()
  @impl true
  def should_sample(ctx, _trace_id, _links, _name, _kind, _attributes, _config) do
    tracestate =
      ctx
      |> Otel.API.Trace.current_span()
      |> Map.get(:tracestate, %Otel.API.Trace.TraceState{})

    {:drop, %{}, tracestate}
  end
end
