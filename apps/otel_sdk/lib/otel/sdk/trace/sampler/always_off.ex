defmodule Otel.SDK.Trace.Sampler.AlwaysOff do
  @moduledoc """
  Sampler that always drops.

  Returns `DROP` for every span.
  Description MUST be "AlwaysOffSampler" (L431).
  """

  @behaviour Otel.SDK.Trace.Sampler

  @impl true
  def setup(_opts), do: []

  @impl true
  def description(_config), do: "AlwaysOffSampler"

  @impl true
  def should_sample(ctx, _trace_id, _links, _name, _kind, _attributes, _config) do
    tracestate =
      ctx
      |> Otel.API.Trace.current_span()
      |> Map.get(:tracestate, %Otel.API.Trace.TraceState{})

    {:drop, %{}, tracestate}
  end
end
