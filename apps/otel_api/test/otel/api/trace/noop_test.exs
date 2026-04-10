defmodule Otel.API.Trace.Tracer.NoopTest do
  use ExUnit.Case, async: true

  alias Otel.API.{Ctx, Trace}
  alias Otel.API.Trace.{SpanContext, Tracer}

  @valid_parent %SpanContext{
    trace_id: 0xFF000000000000000000000000000001,
    span_id: 0xFF00000000000001,
    trace_flags: 1,
    is_remote: true
  }

  describe "start_span/4" do
    test "returns parent SpanContext when parent exists in context" do
      ctx = Trace.set_current_span(Ctx.new(), @valid_parent)
      result = Tracer.Noop.start_span(ctx, {Tracer.Noop, []}, "test_span", [])
      assert result == @valid_parent
    end

    test "returns invalid SpanContext when no parent in context" do
      ctx = Ctx.new()
      result = Tracer.Noop.start_span(ctx, {Tracer.Noop, []}, "test_span", [])
      assert result == %SpanContext{}
      assert SpanContext.valid?(result) == false
    end

    test "returns invalid SpanContext when parent has zero trace_id" do
      parent = %SpanContext{trace_id: 0, span_id: 1}
      ctx = Trace.set_current_span(Ctx.new(), parent)
      result = Tracer.Noop.start_span(ctx, {Tracer.Noop, []}, "test_span", [])
      assert result == %SpanContext{}
    end
  end

  describe "enabled?/2" do
    test "returns false" do
      assert Tracer.Noop.enabled?({Tracer.Noop, []}) == false
    end

    test "returns false with opts" do
      assert Tracer.Noop.enabled?({Tracer.Noop, []}, span_name: "test") == false
    end
  end
end
