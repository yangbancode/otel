defmodule Otel.API.Trace.Tracer.NoopTest do
  use ExUnit.Case, async: true

  @valid_parent %Otel.API.Trace.SpanContext{
    trace_id: 0xFF000000000000000000000000000001,
    span_id: 0xFF00000000000001,
    trace_flags: 1,
    is_remote: true
  }

  describe "start_span/4" do
    test "returns parent SpanContext when parent exists in context" do
      ctx = Otel.API.Trace.set_current_span(%{}, @valid_parent)

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
      ctx = %{}

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
      parent = %Otel.API.Trace.SpanContext{trace_id: 0, span_id: 1}
      ctx = Otel.API.Trace.set_current_span(%{}, parent)

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
