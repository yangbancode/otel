defmodule Otel.SDK.Trace.Sampler.ParentBasedTest do
  use ExUnit.Case, async: true

  # Default ParentBased — root delegates to AlwaysOn; remote/local
  # parent (sampled vs not-sampled) inherits the parent's sampled bit
  # via the default AlwaysOn / AlwaysOff sub-samplers.
  @sampler Otel.SDK.Trace.Sampler.new(
             {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}
           )

  defp parent_ctx(span_id, trace_flags, is_remote) do
    Otel.API.Trace.set_current_span(
      Otel.API.Ctx.new(),
      %Otel.API.Trace.SpanContext{
        trace_id: 123,
        span_id: span_id,
        trace_flags: trace_flags,
        is_remote: is_remote
      }
    )
  end

  defp decision(sampler, ctx),
    do:
      elem(Otel.SDK.Trace.Sampler.should_sample(sampler, ctx, 123, [], "span", :internal, %{}), 0)

  describe "delegates to the right sub-sampler per parent shape" do
    test "no parent → root sampler (AlwaysOn by default)" do
      assert decision(@sampler, %{}) == :record_and_sample
    end

    test "span_id 0 is treated as root" do
      assert decision(@sampler, parent_ctx(0, 1, false)) == :record_and_sample
    end

    # Spec trace/sdk.md L240-L260 — parent's sampled bit drives the
    # default behavior on each of the four parent variants.
    test "remote sampled → record_and_sample; remote unsampled → drop" do
      assert decision(@sampler, parent_ctx(456, 1, true)) == :record_and_sample
      assert decision(@sampler, parent_ctx(456, 0, true)) == :drop
    end

    test "local sampled → record_and_sample; local unsampled → drop" do
      assert decision(@sampler, parent_ctx(456, 1, false)) == :record_and_sample
      assert decision(@sampler, parent_ctx(456, 0, false)) == :drop
    end
  end

  test "custom root sampler is honoured for span with no parent" do
    custom_root =
      Otel.SDK.Trace.Sampler.new(
        {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}}}
      )

    assert decision(custom_root, %{}) == :drop
  end

  test "description/1 includes every sub-sampler" do
    desc = Otel.SDK.Trace.Sampler.description(@sampler)

    assert desc =~ "ParentBased{"
    assert desc =~ "root:AlwaysOnSampler"
    assert desc =~ "remoteParentSampled:AlwaysOnSampler"
    assert desc =~ "remoteParentNotSampled:AlwaysOffSampler"
    assert desc =~ "localParentSampled:AlwaysOnSampler"
    assert desc =~ "localParentNotSampled:AlwaysOffSampler"
  end
end
