defmodule Otel.Metrics.Exemplar.FilterTest do
  use ExUnit.Case, async: true

  defp ctx_with_flags(trace_flags) do
    Otel.Trace.set_current_span(
      Otel.Ctx.new(),
      Otel.Trace.SpanContext.new(%{trace_id: 1, span_id: 1, trace_flags: trace_flags})
    )
  end

  # Spec metrics/sdk.md L1377-L1379 — minikube hardcodes
  # `:trace_based` (samples iff the current span has the W3C
  # sampled bit set). Same wire-format invariant as Trace's
  # `:drop` decision.
  describe "should_sample?/1" do
    test "true iff current span has trace_flags sampled bit set" do
      assert Otel.Metrics.Exemplar.Filter.should_sample?(ctx_with_flags(1))
      refute Otel.Metrics.Exemplar.Filter.should_sample?(ctx_with_flags(0))
      refute Otel.Metrics.Exemplar.Filter.should_sample?(%{})
    end
  end
end
