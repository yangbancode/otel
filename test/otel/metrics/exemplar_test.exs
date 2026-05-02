defmodule Otel.Metrics.ExemplarTest do
  use ExUnit.Case, async: true

  describe "new/4 — extracts trace context when present, omits when absent" do
    test "without an active span, exemplar carries no trace_id / span_id" do
      exemplar =
        Otel.Metrics.Exemplar.new(42, 1000, %{"key" => "val"}, Otel.Ctx.new())

      assert exemplar.value == 42
      assert exemplar.time == 1000
      assert exemplar.filtered_attributes == %{"key" => "val"}
      assert exemplar.trace_id == nil
      assert exemplar.span_id == nil
    end

    test "with a valid current span, exemplar carries its trace_id and span_id" do
      ctx =
        Otel.Trace.set_current_span(
          Otel.Ctx.new(),
          %Otel.Trace.SpanContext{trace_id: 123, span_id: 456, trace_flags: 1}
        )

      exemplar = Otel.Metrics.Exemplar.new(10, 2000, %{}, ctx)
      assert exemplar.trace_id == 123
      assert exemplar.span_id == 456
    end

    test "an invalid span context is ignored (treated as absent)" do
      ctx =
        Otel.Trace.set_current_span(
          Otel.Ctx.new(),
          %Otel.Trace.SpanContext{trace_id: 0, span_id: 0}
        )

      exemplar = Otel.Metrics.Exemplar.new(10, 2000, %{}, ctx)
      assert exemplar.trace_id == nil
      assert exemplar.span_id == nil
    end
  end
end
