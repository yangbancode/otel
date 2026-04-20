defmodule Otel.SDK.Trace.Sampler.ParentBasedTest do
  use ExUnit.Case

  describe "root span (no parent)" do
    test "delegates to root sampler (default AlwaysOn)" do
      sampler =
        Otel.SDK.Trace.Sampler.new(
          {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}
        )

      {decision, _, _} =
        Otel.SDK.Trace.Sampler.should_sample(sampler, %{}, 123, [], "span", :internal, %{})

      assert decision == :record_and_sample
    end

    test "treats span_id 0 as root" do
      parent = %Otel.API.Trace.SpanContext{trace_id: 123, span_id: 0}
      ctx = Otel.API.Trace.set_current_span(%{}, parent)

      sampler =
        Otel.SDK.Trace.Sampler.new(
          {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}
        )

      {decision, _, _} =
        Otel.SDK.Trace.Sampler.should_sample(sampler, ctx, 123, [], "span", :internal, %{})

      assert decision == :record_and_sample
    end

    test "uses custom root sampler" do
      sampler =
        Otel.SDK.Trace.Sampler.new(
          {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOff, %{}}}}
        )

      {decision, _, _} =
        Otel.SDK.Trace.Sampler.should_sample(sampler, %{}, 123, [], "span", :internal, %{})

      assert decision == :drop
    end
  end

  describe "remote parent sampled" do
    test "delegates to remote_parent_sampled (default AlwaysOn)" do
      parent = %Otel.API.Trace.SpanContext{
        trace_id: 123,
        span_id: 456,
        trace_flags: 1,
        is_remote: true
      }

      ctx = Otel.API.Trace.set_current_span(%{}, parent)

      sampler =
        Otel.SDK.Trace.Sampler.new(
          {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}
        )

      {decision, _, _} =
        Otel.SDK.Trace.Sampler.should_sample(sampler, ctx, 123, [], "span", :internal, %{})

      assert decision == :record_and_sample
    end
  end

  describe "remote parent not sampled" do
    test "delegates to remote_parent_not_sampled (default AlwaysOff)" do
      parent = %Otel.API.Trace.SpanContext{
        trace_id: 123,
        span_id: 456,
        trace_flags: 0,
        is_remote: true
      }

      ctx = Otel.API.Trace.set_current_span(%{}, parent)

      sampler =
        Otel.SDK.Trace.Sampler.new(
          {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}
        )

      {decision, _, _} =
        Otel.SDK.Trace.Sampler.should_sample(sampler, ctx, 123, [], "span", :internal, %{})

      assert decision == :drop
    end
  end

  describe "local parent sampled" do
    test "delegates to local_parent_sampled (default AlwaysOn)" do
      parent = %Otel.API.Trace.SpanContext{
        trace_id: 123,
        span_id: 456,
        trace_flags: 1,
        is_remote: false
      }

      ctx = Otel.API.Trace.set_current_span(%{}, parent)

      sampler =
        Otel.SDK.Trace.Sampler.new(
          {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}
        )

      {decision, _, _} =
        Otel.SDK.Trace.Sampler.should_sample(sampler, ctx, 123, [], "span", :internal, %{})

      assert decision == :record_and_sample
    end
  end

  describe "local parent not sampled" do
    test "delegates to local_parent_not_sampled (default AlwaysOff)" do
      parent = %Otel.API.Trace.SpanContext{
        trace_id: 123,
        span_id: 456,
        trace_flags: 0,
        is_remote: false
      }

      ctx = Otel.API.Trace.set_current_span(%{}, parent)

      sampler =
        Otel.SDK.Trace.Sampler.new(
          {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}
        )

      {decision, _, _} =
        Otel.SDK.Trace.Sampler.should_sample(sampler, ctx, 123, [], "span", :internal, %{})

      assert decision == :drop
    end
  end

  describe "description" do
    test "includes all sub-sampler descriptions" do
      sampler =
        Otel.SDK.Trace.Sampler.new(
          {Otel.SDK.Trace.Sampler.ParentBased, %{root: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}}}}
        )

      desc = Otel.SDK.Trace.Sampler.description(sampler)
      assert desc =~ "ParentBased{"
      assert desc =~ "root:AlwaysOnSampler"
      assert desc =~ "remoteParentSampled:AlwaysOnSampler"
      assert desc =~ "remoteParentNotSampled:AlwaysOffSampler"
      assert desc =~ "localParentSampled:AlwaysOnSampler"
      assert desc =~ "localParentNotSampled:AlwaysOffSampler"
    end
  end
end
