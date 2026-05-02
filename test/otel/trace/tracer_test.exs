defmodule Otel.Trace.TracerTest do
  use ExUnit.Case, async: false

  setup do
    Otel.TestSupport.restart_with()

    tracer =
      Otel.Trace.TracerProvider.get_tracer(%Otel.InstrumentationScope{name: "test_lib"})

    %{tracer: tracer}
  end

  test "start_span/4 returns a valid SpanContext, stores the span in ETS with the scope",
       %{tracer: tracer} do
    span_ctx = Otel.Trace.Tracer.start_span(Otel.Ctx.new(), tracer, "test_span", [])

    assert %Otel.Trace.SpanContext{} = span_ctx
    assert Otel.Trace.SpanContext.valid?(span_ctx)

    span = Otel.Trace.SpanStorage.get(span_ctx.span_id)
    assert span.name == "test_span"
    assert span.instrumentation_scope.name == "test_lib"
  end

  # Spec trace/sdk.md L223-L227 MUST: minikube hardcodes a single
  # SpanProcessor, so `enabled?/2` is true while the SDK is up and
  # false after `TracerProvider.shutdown/1`.
  describe "enabled?/2" do
    test "true while SDK is up", %{tracer: tracer} do
      assert Otel.Trace.Tracer.enabled?(tracer)
      assert Otel.Trace.Tracer.enabled?(tracer, span_name: "test")
    end

    test "false after TracerProvider.shutdown/1", %{tracer: tracer} do
      :ok = Otel.Trace.TracerProvider.shutdown()
      refute Otel.Trace.Tracer.enabled?(tracer)
    end
  end
end
