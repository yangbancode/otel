defmodule Otel.API.Trace.LinkTest do
  use ExUnit.Case, async: true

  @span_ctx Otel.API.Trace.SpanContext.new(
              0xFF000000000000000000000000000001,
              0xFF00000000000001
            )

  describe "struct" do
    test "constructs with context only; attributes default to empty map" do
      link = %Otel.API.Trace.Link{context: @span_ctx}

      assert link.context == @span_ctx
      assert link.attributes == %{}
    end

    test "constructs with context and attributes" do
      attrs = %{"key" => "value", "count" => 42}
      link = %Otel.API.Trace.Link{context: @span_ctx, attributes: attrs}

      assert link.context == @span_ctx
      assert link.attributes == attrs
    end

    test "default struct has invalid SpanContext and empty attributes" do
      link = %Otel.API.Trace.Link{}

      assert link.context == %Otel.API.Trace.SpanContext{}
      assert link.attributes == %{}
    end
  end
end
