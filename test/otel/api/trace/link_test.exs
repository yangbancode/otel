defmodule Otel.API.Trace.LinkTest do
  use ExUnit.Case, async: true

  @span_ctx Otel.API.Trace.SpanContext.new(
              0xFF000000000000000000000000000001,
              0xFF00000000000001
            )

  test "default struct has invalid SpanContext and empty attributes" do
    assert %Otel.API.Trace.Link{} ==
             %Otel.API.Trace.Link{context: %Otel.API.Trace.SpanContext{}, attributes: %{}}
  end

  test "context-only literal defaults attributes to %{}" do
    assert %Otel.API.Trace.Link{context: @span_ctx}.attributes == %{}
  end

  test "preserves both fields when set explicitly" do
    attrs = %{"key" => "value", "count" => 42}
    link = %Otel.API.Trace.Link{context: @span_ctx, attributes: attrs}

    assert link.context == @span_ctx
    assert link.attributes == attrs
  end
end
