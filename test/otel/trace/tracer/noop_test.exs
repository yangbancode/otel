defmodule Otel.Trace.Tracer.NoopTest do
  use ExUnit.Case, async: true

  @tracer {Otel.Trace.Tracer.Noop, []}
  @valid_parent %Otel.Trace.SpanContext{
    trace_id: 0xFF000000000000000000000000000001,
    span_id: 0xFF00000000000001,
    trace_flags: 1,
    is_remote: true
  }

  describe "start_span/4" do
    # Spec trace/api.md L865-L866 — return the parent's SpanContext
    # when one is present in the Context.
    test "returns the current span when its trace_id is non-zero" do
      ctx = Otel.Trace.set_current_span(Otel.Ctx.new(), @valid_parent)

      assert Otel.Trace.Tracer.Noop.start_span(ctx, @tracer, "n", []) == @valid_parent
    end

    # Spec trace/api.md L869-L871 — empty non-recording SpanContext
    # when the Context has no Span (or only an invalid one).
    test "returns the default SpanContext when no parent or parent has zero trace_id" do
      empty_ctx = Otel.Ctx.new()
      bad_parent = %Otel.Trace.SpanContext{trace_id: 0, span_id: 1}
      bad_ctx = Otel.Trace.set_current_span(empty_ctx, bad_parent)

      assert Otel.Trace.Tracer.Noop.start_span(empty_ctx, @tracer, "n", []) ==
               %Otel.Trace.SpanContext{}

      assert Otel.Trace.Tracer.Noop.start_span(bad_ctx, @tracer, "n", []) ==
               %Otel.Trace.SpanContext{}
    end
  end

  describe "with_span/5" do
    test "invokes the function with the started SpanContext and detaches the context" do
      ctx = Otel.Trace.set_current_span(Otel.Ctx.new(), @valid_parent)

      result =
        Otel.Trace.Tracer.Noop.with_span(ctx, @tracer, "n", [], fn span_ctx ->
          {:body_ran, span_ctx, Otel.Trace.current_span(Otel.Ctx.current())}
        end)

      assert {:body_ran, @valid_parent, @valid_parent} = result
      # Detach restored the previous (empty) global Context.
      assert Otel.Trace.current_span(Otel.Ctx.current()) ==
               %Otel.Trace.SpanContext{}
    end
  end

  describe "enabled?/2" do
    # Spec trace/api.md L201-L213 — a no-op tracer is by definition
    # not enabled; opts cannot change the answer.
    test "always false, with or without opts" do
      refute Otel.Trace.Tracer.Noop.enabled?(@tracer)
      refute Otel.Trace.Tracer.Noop.enabled?(@tracer, span_name: "test")
    end
  end
end
