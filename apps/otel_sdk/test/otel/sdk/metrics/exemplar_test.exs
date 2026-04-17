defmodule Otel.SDK.Metrics.ExemplarTest do
  use ExUnit.Case, async: true

  describe "new/4" do
    test "creates exemplar with value and attributes" do
      ctx = Otel.API.Ctx.new()

      attrs = [
        Otel.API.Common.Attribute.new("key", Otel.API.Common.AnyValue.string("val"))
      ]

      exemplar = Otel.SDK.Metrics.Exemplar.new(42, 1000, attrs, ctx)
      assert exemplar.value == 42
      assert exemplar.time == 1000
      assert exemplar.filtered_attributes == attrs
      assert exemplar.trace_id == nil
      assert exemplar.span_id == nil
    end

    test "extracts trace context when span is active" do
      ctx = Otel.API.Ctx.new()

      trace_id = Otel.API.Trace.TraceId.new(<<123::128>>)
      span_id = Otel.API.Trace.SpanId.new(<<456::64>>)

      span_ctx = %Otel.API.Trace.SpanContext{
        trace_id: trace_id,
        span_id: span_id,
        trace_flags: 1
      }

      ctx = Otel.API.Trace.set_current_span(ctx, span_ctx)
      exemplar = Otel.SDK.Metrics.Exemplar.new(10, 2000, [], ctx)
      assert exemplar.trace_id == trace_id
      assert exemplar.span_id == span_id
    end

    test "no trace info when span context is invalid" do
      ctx = Otel.API.Ctx.new()

      invalid = %Otel.API.Trace.SpanContext{
        trace_id: Otel.API.Trace.TraceId.invalid(),
        span_id: Otel.API.Trace.SpanId.invalid()
      }

      ctx = Otel.API.Trace.set_current_span(ctx, invalid)
      exemplar = Otel.SDK.Metrics.Exemplar.new(10, 2000, [], ctx)
      assert exemplar.trace_id == nil
      assert exemplar.span_id == nil
    end
  end
end
