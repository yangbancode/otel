defmodule Otel.API.Trace.LinkTest do
  use ExUnit.Case, async: true

  @span_ctx Otel.API.Trace.SpanContext.new(
              0xFF000000000000000000000000000001,
              0xFF00000000000001
            )

  describe "new/1,2" do
    test "creates a link with default empty attributes" do
      link = Otel.API.Trace.Link.new(@span_ctx)

      assert link.context == @span_ctx
      assert link.attributes == %{}
    end

    test "creates a link with attributes" do
      attrs = %{"key" => "value", "count" => 42}
      link = Otel.API.Trace.Link.new(@span_ctx, attrs)

      assert link.context == @span_ctx
      assert link.attributes == attrs
    end
  end

  describe "struct defaults" do
    test "default struct has invalid SpanContext and empty attributes" do
      link = %Otel.API.Trace.Link{}

      assert link.context == %Otel.API.Trace.SpanContext{}
      assert link.attributes == %{}
    end
  end
end
