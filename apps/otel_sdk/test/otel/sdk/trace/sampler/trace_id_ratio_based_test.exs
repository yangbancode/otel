defmodule Otel.SDK.Trace.Sampler.TraceIdRatioBasedTest do
  use ExUnit.Case, async: true

  @sampler_module Otel.SDK.Trace.Sampler.TraceIdRatioBased

  defp random_trace_id do
    Otel.API.Trace.TraceId.new(:crypto.strong_rand_bytes(16))
  end

  describe "setup/1" do
    test "accepts probability 0.0" do
      sampler = Otel.SDK.Trace.Sampler.new({@sampler_module, 0.0})
      assert {_, _, %{probability: +0.0}} = sampler
    end

    test "accepts probability 1.0" do
      sampler = Otel.SDK.Trace.Sampler.new({@sampler_module, 1.0})
      assert {_, _, %{probability: 1.0}} = sampler
    end

    test "accepts probability 0.5" do
      sampler = Otel.SDK.Trace.Sampler.new({@sampler_module, 0.5})
      assert {_, _, %{probability: 0.5}} = sampler
    end
  end

  describe "description/1" do
    test "returns TraceIdRatioBased{ratio} format" do
      sampler = Otel.SDK.Trace.Sampler.new({@sampler_module, 0.0001})
      desc = Otel.SDK.Trace.Sampler.description(sampler)
      assert desc =~ "TraceIdRatioBased{"
      assert desc =~ "0.000100"
    end
  end

  describe "should_sample/7" do
    test "probability 1.0 always samples" do
      sampler = Otel.SDK.Trace.Sampler.new({@sampler_module, 1.0})

      for _ <- 1..100 do
        trace_id = random_trace_id()

        {decision, _, _} =
          Otel.SDK.Trace.Sampler.should_sample(sampler, %{}, trace_id, [], "span", :internal, [])

        assert decision == :record_and_sample
      end
    end

    test "probability 0.0 always drops" do
      sampler = Otel.SDK.Trace.Sampler.new({@sampler_module, 0.0})

      for _ <- 1..100 do
        trace_id = random_trace_id()

        {decision, _, _} =
          Otel.SDK.Trace.Sampler.should_sample(sampler, %{}, trace_id, [], "span", :internal, [])

        assert decision == :drop
      end
    end

    test "drops when trace_id is invalid" do
      sampler = Otel.SDK.Trace.Sampler.new({@sampler_module, 1.0})

      {decision, _, _} =
        Otel.SDK.Trace.Sampler.should_sample(
          sampler,
          %{},
          Otel.API.Trace.TraceId.invalid(),
          [],
          "span",
          :internal,
          []
        )

      assert decision == :drop
    end

    test "deterministic: same trace_id gives same decision" do
      sampler = Otel.SDK.Trace.Sampler.new({@sampler_module, 0.5})
      trace_id = random_trace_id()

      {decision1, _, _} =
        Otel.SDK.Trace.Sampler.should_sample(sampler, %{}, trace_id, [], "span", :internal, [])

      {decision2, _, _} =
        Otel.SDK.Trace.Sampler.should_sample(sampler, %{}, trace_id, [], "span", :internal, [])

      assert decision1 == decision2
    end

    test "higher ratio samples all traces that lower ratio would" do
      low = Otel.SDK.Trace.Sampler.new({@sampler_module, 0.1})
      high = Otel.SDK.Trace.Sampler.new({@sampler_module, 0.5})

      for _ <- 1..200 do
        trace_id = random_trace_id()

        {low_decision, _, _} =
          Otel.SDK.Trace.Sampler.should_sample(low, %{}, trace_id, [], "span", :internal, [])

        {high_decision, _, _} =
          Otel.SDK.Trace.Sampler.should_sample(high, %{}, trace_id, [], "span", :internal, [])

        if low_decision == :record_and_sample do
          assert high_decision == :record_and_sample
        end
      end
    end
  end
end
