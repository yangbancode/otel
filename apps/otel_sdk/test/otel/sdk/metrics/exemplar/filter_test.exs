defmodule Otel.SDK.Metrics.Exemplar.FilterTest do
  use ExUnit.Case, async: true

  describe "should_sample?/2" do
    test "always_on returns true" do
      assert Otel.SDK.Metrics.Exemplar.Filter.should_sample?(:always_on, %{})
    end

    test "always_off returns false" do
      refute Otel.SDK.Metrics.Exemplar.Filter.should_sample?(:always_off, %{})
    end

    test "trace_based returns true when span is sampled" do
      ctx = %{}

      span_ctx = %Otel.API.Trace.SpanContext{
        trace_id: 1,
        span_id: 1,
        trace_flags: 1
      }

      ctx = Otel.API.Trace.set_current_span(ctx, span_ctx)
      assert Otel.SDK.Metrics.Exemplar.Filter.should_sample?(:trace_based, ctx)
    end

    test "trace_based returns false when span is not sampled" do
      ctx = %{}

      span_ctx = %Otel.API.Trace.SpanContext{
        trace_id: 1,
        span_id: 1,
        trace_flags: 0
      }

      ctx = Otel.API.Trace.set_current_span(ctx, span_ctx)
      refute Otel.SDK.Metrics.Exemplar.Filter.should_sample?(:trace_based, ctx)
    end

    test "trace_based returns false when no span context" do
      refute Otel.SDK.Metrics.Exemplar.Filter.should_sample?(:trace_based, %{})
    end
  end
end
