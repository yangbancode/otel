defmodule Otel.SDK.Metrics.ExemplarTest do
  use ExUnit.Case, async: true

  describe "new/4" do
    test "creates exemplar with value and attributes" do
      ctx = Otel.API.Ctx.new()
      exemplar = Otel.SDK.Metrics.Exemplar.new(42, 1000, %{"key" => "val"}, ctx)
      assert exemplar.value == 42
      assert exemplar.time == 1000
      assert exemplar.filtered_attributes == %{"key" => "val"}
      assert exemplar.trace_id == nil
      assert exemplar.span_id == nil
    end

    test "extracts trace context when span is active" do
      ctx = Otel.API.Ctx.new()

      span_ctx = %Otel.API.Trace.SpanContext{
        trace_id: 123,
        span_id: 456,
        trace_flags: 1
      }

      ctx = Otel.API.Trace.set_current_span(ctx, span_ctx)
      exemplar = Otel.SDK.Metrics.Exemplar.new(10, 2000, %{}, ctx)
      assert exemplar.trace_id == 123
      assert exemplar.span_id == 456
    end

    test "no trace info when span context is invalid" do
      ctx = Otel.API.Ctx.new()
      invalid = %Otel.API.Trace.SpanContext{trace_id: 0, span_id: 0}
      ctx = Otel.API.Trace.set_current_span(ctx, invalid)
      exemplar = Otel.SDK.Metrics.Exemplar.new(10, 2000, %{}, ctx)
      assert exemplar.trace_id == nil
      assert exemplar.span_id == nil
    end
  end
end
