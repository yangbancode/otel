defmodule Otel.SDK.Metrics.Exemplar.FilterTest do
  use ExUnit.Case, async: true

  defp ctx_with_flags(trace_flags) do
    Otel.API.Trace.set_current_span(
      Otel.API.Ctx.new(),
      %Otel.API.Trace.SpanContext{trace_id: 1, span_id: 1, trace_flags: trace_flags}
    )
  end

  # Spec metrics/sdk.md L1377-L1379 — three filters: :always_on,
  # :always_off, :trace_based (samples iff current span is sampled).

  describe "should_sample?/2" do
    test ":always_on / :always_off ignore the context" do
      assert Otel.SDK.Metrics.Exemplar.Filter.should_sample?(:always_on, %{})
      refute Otel.SDK.Metrics.Exemplar.Filter.should_sample?(:always_off, %{})
    end

    test ":trace_based returns true iff the current span has trace_flags sampled bit set" do
      assert Otel.SDK.Metrics.Exemplar.Filter.should_sample?(:trace_based, ctx_with_flags(1))
      refute Otel.SDK.Metrics.Exemplar.Filter.should_sample?(:trace_based, ctx_with_flags(0))
      refute Otel.SDK.Metrics.Exemplar.Filter.should_sample?(:trace_based, %{})
    end
  end
end
