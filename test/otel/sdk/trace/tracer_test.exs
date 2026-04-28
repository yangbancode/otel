defmodule Otel.SDK.Trace.TracerTest do
  use ExUnit.Case

  setup do
    # Disable the default OTLP + Batch wiring so the supervised
    # TracerProvider boots with an empty processor list — the
    # `enabled?/2` tests below depend on the no-processor leg.
    Application.stop(:otel)
    Application.put_env(:otel, :trace, exporter: :none)
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      Application.delete_env(:otel, :trace)
      Application.ensure_all_started(:otel)
    end)

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
      key = {__MODULE__, :test_processors, make_ref()}
      :persistent_term.put(key, [{Otel.SDK.Trace.SpanProcessor.Simple, %{pid: self()}}])
      on_exit(fn -> :persistent_term.erase(key) end)

      tracer = {Otel.SDK.Trace.Tracer, %{processors_key: key}}
      assert Otel.SDK.Trace.Tracer.enabled?(tracer) == true
    end
  end
end
