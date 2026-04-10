defmodule Otel.SDK.Trace.Sampler.ParentBased do
  @moduledoc """
  Sampler decorator that delegates based on parent span state.

  Routes to different sub-samplers depending on whether the parent
  is absent, remote/local, and sampled/not-sampled.
  """

  @behaviour Otel.SDK.Trace.Sampler

  @impl true
  def setup(opts) do
    root_spec = Map.get(opts, :root, {Otel.SDK.Trace.Sampler.AlwaysOn, %{}})

    %{
      root: Otel.SDK.Trace.Sampler.new(root_spec),
      remote_parent_sampled:
        Otel.SDK.Trace.Sampler.new(
          Map.get(opts, :remote_parent_sampled, {Otel.SDK.Trace.Sampler.AlwaysOn, %{}})
        ),
      remote_parent_not_sampled:
        Otel.SDK.Trace.Sampler.new(
          Map.get(opts, :remote_parent_not_sampled, {Otel.SDK.Trace.Sampler.AlwaysOff, %{}})
        ),
      local_parent_sampled:
        Otel.SDK.Trace.Sampler.new(
          Map.get(opts, :local_parent_sampled, {Otel.SDK.Trace.Sampler.AlwaysOn, %{}})
        ),
      local_parent_not_sampled:
        Otel.SDK.Trace.Sampler.new(
          Map.get(opts, :local_parent_not_sampled, {Otel.SDK.Trace.Sampler.AlwaysOff, %{}})
        )
    }
  end

  @impl true
  def description(config) do
    "ParentBased{root:#{Otel.SDK.Trace.Sampler.description(config.root)}" <>
      ",remoteParentSampled:#{Otel.SDK.Trace.Sampler.description(config.remote_parent_sampled)}" <>
      ",remoteParentNotSampled:#{Otel.SDK.Trace.Sampler.description(config.remote_parent_not_sampled)}" <>
      ",localParentSampled:#{Otel.SDK.Trace.Sampler.description(config.local_parent_sampled)}" <>
      ",localParentNotSampled:#{Otel.SDK.Trace.Sampler.description(config.local_parent_not_sampled)}}"
  end

  @impl true
  def should_sample(ctx, trace_id, links, name, kind, attributes, config) do
    parent_span_ctx = Otel.API.Trace.current_span(ctx)
    sampler_key = select_sampler(parent_span_ctx)
    delegate = Map.fetch!(config, sampler_key)
    Otel.SDK.Trace.Sampler.should_sample(delegate, ctx, trace_id, links, name, kind, attributes)
  end

  defp select_sampler(%Otel.API.Trace.SpanContext{trace_id: 0}), do: :root
  defp select_sampler(%Otel.API.Trace.SpanContext{span_id: 0}), do: :root

  defp select_sampler(%Otel.API.Trace.SpanContext{is_remote: true, trace_flags: trace_flags}) do
    if Bitwise.band(trace_flags, 1) != 0 do
      :remote_parent_sampled
    else
      :remote_parent_not_sampled
    end
  end

  defp select_sampler(%Otel.API.Trace.SpanContext{trace_flags: trace_flags}) do
    if Bitwise.band(trace_flags, 1) != 0 do
      :local_parent_sampled
    else
      :local_parent_not_sampled
    end
  end
end
