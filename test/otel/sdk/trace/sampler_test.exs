defmodule Otel.SDK.Trace.SamplerTest do
  use ExUnit.Case, async: true

  @trace_id 0xC0FFEEDEADBEEF0123456789ABCDEF
  @parent_span_id 0xABCDEF0123456789

  describe "description/0" do
    test "returns the spec-style ParentBased descriptor with all five branches" do
      assert Otel.SDK.Trace.Sampler.description() ==
               "ParentBased{root:AlwaysOnSampler" <>
                 ",remoteParentSampled:AlwaysOnSampler" <>
                 ",remoteParentNotSampled:AlwaysOffSampler" <>
                 ",localParentSampled:AlwaysOnSampler" <>
                 ",localParentNotSampled:AlwaysOffSampler}"
    end
  end

  describe "should_sample/6 — root span (no parent)" do
    test "samples the root span" do
      ctx = Otel.API.Ctx.new()

      assert {:record_and_sample, %{}, %Otel.API.Trace.TraceState{}} =
               Otel.SDK.Trace.Sampler.should_sample(ctx, @trace_id, [], "root", :internal, %{})
    end
  end

  describe "should_sample/6 — parent sampled" do
    test "samples a child of a remote sampled parent" do
      assert {:record_and_sample, %{}, _tracestate} =
               sample_with_parent(is_remote: true, sampled?: true)
    end

    test "samples a child of a local sampled parent" do
      assert {:record_and_sample, %{}, _tracestate} =
               sample_with_parent(is_remote: false, sampled?: true)
    end
  end

  describe "should_sample/6 — parent not sampled" do
    test "drops a child of a remote not-sampled parent" do
      assert {:drop, %{}, _tracestate} =
               sample_with_parent(is_remote: true, sampled?: false)
    end

    test "drops a child of a local not-sampled parent" do
      assert {:drop, %{}, _tracestate} =
               sample_with_parent(is_remote: false, sampled?: false)
    end
  end

  describe "should_sample/6 — tracestate propagation" do
    test "carries the parent tracestate through unchanged" do
      tracestate =
        Otel.API.Trace.TraceState.new() |> Otel.API.Trace.TraceState.add("vendor", "value")

      parent = %Otel.API.Trace.SpanContext{
        trace_id: @trace_id,
        span_id: @parent_span_id,
        trace_flags: 1,
        is_remote: true,
        tracestate: tracestate
      }

      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      assert {:record_and_sample, %{}, ^tracestate} =
               Otel.SDK.Trace.Sampler.should_sample(ctx, @trace_id, [], "child", :internal, %{})
    end
  end

  defp sample_with_parent(is_remote: is_remote, sampled?: sampled?) do
    parent = %Otel.API.Trace.SpanContext{
      trace_id: @trace_id,
      span_id: @parent_span_id,
      trace_flags: if(sampled?, do: 1, else: 0),
      is_remote: is_remote,
      tracestate: Otel.API.Trace.TraceState.new()
    }

    ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)
    Otel.SDK.Trace.Sampler.should_sample(ctx, @trace_id, [], "child", :internal, %{})
  end
end
