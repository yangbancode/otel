defmodule Otel.Trace.TracerTest do
  use ExUnit.Case, async: false

  setup do
    Otel.TestSupport.restart_with()

    tracer =
      Otel.Trace.TracerProvider.get_tracer()

    %{tracer: tracer}
  end

  test "start_span/4 returns a valid SpanContext, stores the span in ETS with the scope",
       %{tracer: tracer} do
    span_ctx = Otel.Trace.Tracer.start_span(Otel.Ctx.new(), tracer, "test_span", [])

    assert %Otel.Trace.SpanContext{} = span_ctx
    assert Otel.Trace.SpanContext.valid?(span_ctx)

    span = Otel.Trace.SpanStorage.get(span_ctx.span_id)
    assert span.name == "test_span"
    assert span.instrumentation_scope.name == "otel"
  end
end
