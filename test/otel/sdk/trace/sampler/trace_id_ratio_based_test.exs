defmodule Otel.SDK.Trace.Sampler.TraceIdRatioBasedTest do
  use ExUnit.Case, async: true

  @sampler_module Otel.SDK.Trace.Sampler.TraceIdRatioBased
  @random_trace_id_max Bitwise.bsl(2, 127) - 1

  defp sampler(probability), do: Otel.SDK.Trace.Sampler.new({@sampler_module, probability})

  defp decision(sampler, trace_id),
    do:
      elem(
        Otel.SDK.Trace.Sampler.should_sample(sampler, %{}, trace_id, [], "n", :internal, %{}),
        0
      )

  describe "setup/1 — accepts probabilities in [0.0, 1.0]" do
    test "round-trips at the boundaries and a midpoint" do
      assert {_, _, %{probability: +0.0}} = sampler(0.0)
      assert {_, _, %{probability: 1.0}} = sampler(1.0)
      assert {_, _, %{probability: 0.5}} = sampler(0.5)
    end
  end

  test ~s|description/1 returns "TraceIdRatioBased{<formatted ratio>}"| do
    desc = Otel.SDK.Trace.Sampler.description(sampler(0.0001))

    assert desc =~ "TraceIdRatioBased{"
    assert desc =~ "0.000100"
  end

  describe "should_sample/7" do
    test "probability 1.0 samples every trace_id; 0.0 drops every trace_id" do
      always = sampler(1.0)
      never = sampler(0.0)

      for _ <- 1..50 do
        trace_id = :rand.uniform(@random_trace_id_max)
        assert decision(always, trace_id) == :record_and_sample
        assert decision(never, trace_id) == :drop
      end
    end

    test "trace_id 0 always drops (cannot derive a valid hash)" do
      assert decision(sampler(1.0), 0) == :drop
    end

    test "deterministic: same trace_id yields the same decision" do
      s = sampler(0.5)
      trace_id = :rand.uniform(@random_trace_id_max)

      assert decision(s, trace_id) == decision(s, trace_id)
    end

    test "monotonicity: a higher ratio samples every trace_id a lower ratio would" do
      low = sampler(0.1)
      high = sampler(0.5)

      for _ <- 1..200 do
        trace_id = :rand.uniform(@random_trace_id_max)

        if decision(low, trace_id) == :record_and_sample do
          assert decision(high, trace_id) == :record_and_sample
        end
      end
    end
  end
end
