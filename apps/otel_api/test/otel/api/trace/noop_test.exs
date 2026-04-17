defmodule Otel.API.Trace.Tracer.NoopTest do
  use ExUnit.Case, async: true

  @valid_parent %Otel.API.Trace.SpanContext{
    trace_id: Otel.API.Trace.TraceId.new(<<0xFF000000000000000000000000000001::128>>),
    span_id: Otel.API.Trace.SpanId.new(<<0xFF00000000000001::64>>),
    trace_flags: 1,
    is_remote: true
  }

  describe "start_span/4" do
    test "returns parent SpanContext when parent exists in context" do
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), @valid_parent)

      result =
        Otel.API.Trace.Tracer.Noop.start_span(
          ctx,
          {Otel.API.Trace.Tracer.Noop, []},
          "test_span",
          []
        )

      assert result == @valid_parent
    end

    test "returns invalid SpanContext when no parent in context" do
      ctx = Otel.API.Ctx.new()

      result =
        Otel.API.Trace.Tracer.Noop.start_span(
          ctx,
          {Otel.API.Trace.Tracer.Noop, []},
          "test_span",
          []
        )

      assert result == %Otel.API.Trace.SpanContext{}
      assert Otel.API.Trace.SpanContext.valid?(result) == false
    end

    test "returns invalid SpanContext when parent has zero trace_id" do
      parent = %Otel.API.Trace.SpanContext{
        trace_id: Otel.API.Trace.TraceId.invalid(),
        span_id: Otel.API.Trace.SpanId.new(<<1::64>>)
      }

      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), parent)

      result =
        Otel.API.Trace.Tracer.Noop.start_span(
          ctx,
          {Otel.API.Trace.Tracer.Noop, []},
          "test_span",
          []
        )

      assert result == %Otel.API.Trace.SpanContext{}
    end
  end

  describe "enabled?/2" do
    test "returns false" do
      assert Otel.API.Trace.Tracer.Noop.enabled?({Otel.API.Trace.Tracer.Noop, []}) == false
    end

    test "returns false with opts" do
      assert Otel.API.Trace.Tracer.Noop.enabled?({Otel.API.Trace.Tracer.Noop, []},
               span_name: "test"
             ) == false
    end
  end
end
