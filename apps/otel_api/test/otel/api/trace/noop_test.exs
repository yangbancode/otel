defmodule Otel.API.Trace.NoopTest do
  use ExUnit.Case, async: true

  alias Otel.API.Trace.{Noop, SpanContext}

  @valid_parent %SpanContext{
    trace_id: 0xFF000000000000000000000000000001,
    span_id: 0xFF00000000000001,
    trace_flags: 1,
    is_remote: true
  }

  describe "start_span/4" do
    test "returns parent SpanContext when parent exists in context" do
      ctx = %{span: @valid_parent}
      result = Noop.start_span(ctx, {Noop, []}, "test_span", [])
      assert result == @valid_parent
    end

    test "returns invalid SpanContext when no parent in context" do
      ctx = %{}
      result = Noop.start_span(ctx, {Noop, []}, "test_span", [])
      assert result == %SpanContext{}
      assert SpanContext.valid?(result) == false
    end

    test "returns invalid SpanContext when parent has zero trace_id" do
      ctx = %{span: %SpanContext{trace_id: 0, span_id: 1}}
      result = Noop.start_span(ctx, {Noop, []}, "test_span", [])
      assert result == %SpanContext{}
    end
  end

  describe "enabled?/1" do
    test "returns false" do
      assert Noop.enabled?({Noop, []}) == false
    end
  end
end
