defmodule Otel.SDK.Trace.TracerTest do
  use ExUnit.Case

  setup do
    Application.stop(:otel_sdk)
    Application.ensure_all_started(:otel_sdk)

    {_module, tracer_config} =
      Otel.SDK.Trace.TracerProvider.get_tracer(
        Otel.SDK.Trace.TracerProvider,
        %Otel.API.InstrumentationScope{name: "test_lib"}
      )

    %{tracer: {Otel.SDK.Trace.Tracer, tracer_config}}
  end

  describe "start_span/4" do
    test "returns valid SpanContext", %{tracer: tracer} do
      ctx = Otel.API.Ctx.new()
      span_ctx = Otel.SDK.Trace.Tracer.start_span(ctx, tracer, "test_span", [])

      assert %Otel.API.Trace.SpanContext{} = span_ctx
      assert Otel.API.Trace.SpanContext.valid?(span_ctx)
    end

    test "stores span in ETS", %{tracer: tracer} do
      ctx = Otel.API.Ctx.new()
      span_ctx = Otel.SDK.Trace.Tracer.start_span(ctx, tracer, "stored_span", [])

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span != nil
      assert span.name == "stored_span"
    end

    test "sets instrumentation scope on span", %{tracer: tracer} do
      ctx = Otel.API.Ctx.new()
      span_ctx = Otel.SDK.Trace.Tracer.start_span(ctx, tracer, "scoped_span", [])

      span = Otel.SDK.Trace.SpanStorage.get(span_ctx.span_id)
      assert span.instrumentation_scope.name == "test_lib"
    end
  end

  describe "enabled?/2 (spec trace/sdk.md L223-L227 MUST)" do
    test "returns false when no SpanProcessors are registered", %{tracer: tracer} do
      # Default TracerProvider config has `processors: []`. Spec
      # MUST: enabled? returns false when no SpanProcessors.
      assert Otel.SDK.Trace.Tracer.enabled?(tracer) == false
    end

    test "returns false with opts when no processors", %{tracer: tracer} do
      assert Otel.SDK.Trace.Tracer.enabled?(tracer, span_name: "test") == false
    end

    test "returns true when at least one SpanProcessor is registered" do
      processors = [{Otel.SDK.Trace.SpanProcessor.Simple, %{exporter: nil}}]
      tracer = {Otel.SDK.Trace.Tracer, %{processors: processors}}
      assert Otel.SDK.Trace.Tracer.enabled?(tracer) == true
    end
  end
end
