defmodule Otel.Metrics.ExemplarTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "default struct has zeros and nils" do
      assert Otel.Metrics.Exemplar.new() ==
               %Otel.Metrics.Exemplar{
                 value: 0,
                 time: 0,
                 filtered_attributes: %{},
                 trace_id: nil,
                 span_id: nil
               }
    end

    test "preserves caller-supplied trace_id / span_id verbatim" do
      exemplar =
        Otel.Metrics.Exemplar.new(%{
          value: 42,
          time: 1000,
          filtered_attributes: %{"key" => "val"},
          trace_id: 123,
          span_id: 456
        })

      assert exemplar.value == 42
      assert exemplar.time == 1000
      assert exemplar.filtered_attributes == %{"key" => "val"}
      assert exemplar.trace_id == 123
      assert exemplar.span_id == 456
    end
  end

  describe "trace_info/1 — extract current span ids from ctx" do
    test "without an active span, returns {nil, nil}" do
      assert Otel.Metrics.Exemplar.trace_info(Otel.Ctx.new()) == {nil, nil}
    end

    test "with a valid current span, returns its trace_id and span_id" do
      ctx =
        Otel.Trace.set_current_span(
          Otel.Ctx.new(),
          Otel.Trace.SpanContext.new(%{trace_id: 123, span_id: 456, trace_flags: 1})
        )

      assert Otel.Metrics.Exemplar.trace_info(ctx) == {123, 456}
    end

    test "an invalid span context yields {nil, nil}" do
      ctx =
        Otel.Trace.set_current_span(
          Otel.Ctx.new(),
          Otel.Trace.SpanContext.new(%{trace_id: 0, span_id: 0})
        )

      assert Otel.Metrics.Exemplar.trace_info(ctx) == {nil, nil}
    end
  end
end
