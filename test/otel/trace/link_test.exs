defmodule Otel.Trace.LinkTest do
  use ExUnit.Case, async: true

  @span_ctx Otel.Trace.SpanContext.new(%{
              trace_id: 0xFF000000000000000000000000000001,
              span_id: 0xFF00000000000001
            })

  test "new/0 builds a Link with invalid SpanContext and empty attributes" do
    link = Otel.Trace.Link.new()
    assert link.context == Otel.Trace.SpanContext.new()
    assert link.attributes == %{}
    assert link.dropped_attributes_count == 0
  end

  test "context-only opts default attributes to %{}" do
    assert Otel.Trace.Link.new(%{context: @span_ctx}).attributes == %{}
  end

  test "preserves both fields when set explicitly" do
    attrs = %{"key" => "value", "count" => 42}
    link = Otel.Trace.Link.new(%{context: @span_ctx, attributes: attrs})

    assert link.context == @span_ctx
    assert link.attributes == attrs
  end
end
