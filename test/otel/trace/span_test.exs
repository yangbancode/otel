defmodule Otel.Trace.SpanTest do
  use ExUnit.Case, async: true

  @valid_ctx Otel.Trace.SpanContext.new(%{
               trace_id: 0xFF000000000000000000000000000001,
               span_id: 0xFF00000000000001
             })

  @invalid_ctx Otel.Trace.SpanContext.new()

  describe "get_context/1" do
    test "returns valid SpanContext as-is" do
      assert Otel.Trace.Span.get_context(@valid_ctx) == @valid_ctx
    end

    test "returns invalid SpanContext as-is" do
      assert Otel.Trace.Span.get_context(@invalid_ctx) == @invalid_ctx
    end
  end
end
