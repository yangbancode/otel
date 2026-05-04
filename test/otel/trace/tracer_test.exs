defmodule Otel.Trace.TracerTest do
  use ExUnit.Case, async: false

  setup do
    Otel.TestSupport.restart_with()
    :ok
  end

  test "start_span/3 returns a valid SpanContext and stores the span in ETS with the hardcoded scope" do
    span_ctx = Otel.Trace.Tracer.start_span(Otel.Ctx.new(), "test_span", [])

    assert %Otel.Trace.SpanContext{} = span_ctx
    assert Otel.Trace.SpanContext.valid?(span_ctx)

    span = Otel.Trace.SpanStorage.get_active(span_ctx.span_id)
    assert span.name == "test_span"
    assert span.instrumentation_scope.name == "otel"
  end
end
