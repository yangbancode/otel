defmodule Otel.SDK.Trace.Sampler.AlwaysOn do
  @moduledoc """
  Sampler that always records and samples.

  Returns `RECORD_AND_SAMPLE` for every span.
  Description MUST be "AlwaysOnSampler" (L426).
  """

  @behaviour Otel.SDK.Trace.Sampler

  @impl true
  def setup(_opts), do: []

  @impl true
  def description(_config), do: "AlwaysOnSampler"

  @impl true
  def should_sample(ctx, _trace_id, _links, _name, _kind, _attributes, _config) do
    tracestate =
      ctx
      |> Otel.API.Trace.current_span()
      |> Map.get(:tracestate, %Otel.API.Trace.TraceState{})

    {:record_and_sample, %{}, tracestate}
  end
end
