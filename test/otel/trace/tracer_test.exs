defmodule Otel.Trace.TracerTest do
  use ExUnit.Case, async: false

  setup do
    # `enabled?` tests below depend on the no-processor leg, so boot
    # the supervised TracerProvider with an empty processor list.
    Application.stop(:otel)
    Application.put_env(:otel, :trace, processors: [])
    Application.ensure_all_started(:otel)

    on_exit(fn ->
      Application.stop(:otel)
      Application.delete_env(:otel, :trace)
      Application.ensure_all_started(:otel)
    end)

    tracer =
      Otel.Trace.TracerProvider.get_tracer(
        Otel.Trace.TracerProvider,
        %Otel.InstrumentationScope{name: "test_lib"}
      )

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

  # Spec trace/sdk.md L223-L227 MUST: enabled?/2 returns false iff
  # the Tracer has no SpanProcessors registered.
  describe "enabled?/2" do
    test "false when no SpanProcessors are registered (any opts)", %{tracer: tracer} do
      refute Otel.Trace.Tracer.enabled?(tracer)
      refute Otel.Trace.Tracer.enabled?(tracer, span_name: "test")
    end

    test "true when at least one SpanProcessor is registered" do
      key = {__MODULE__, :test_processors, make_ref()}
      :persistent_term.put(key, [{Otel.Trace.SpanProcessor.Simple, %{pid: self()}}])
      on_exit(fn -> :persistent_term.erase(key) end)

      assert Otel.Trace.Tracer.enabled?(%Otel.Trace.Tracer{processors_key: key})
    end
  end
end
