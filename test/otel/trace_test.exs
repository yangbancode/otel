defmodule Otel.TraceTest do
  use ExUnit.Case, async: true

  @valid_span_ctx Otel.Trace.SpanContext.new(%{
                    trace_id: 0xFF000000000000000000000000000001,
                    span_id: 0xFF00000000000001,
                    trace_flags: 1
                  })

  setup do
    Otel.Ctx.attach(Otel.Ctx.new())
    :ok
  end

  describe "current_span / set_current_span" do
    test "explicit context: round-trip; default Span when none set; immutable update" do
      ctx = Otel.Ctx.new()
      assert Otel.Trace.current_span(ctx) == Otel.Trace.SpanContext.new()

      ctx_with = Otel.Trace.set_current_span(ctx, @valid_span_ctx)

      assert Otel.Trace.current_span(ctx) == Otel.Trace.SpanContext.new()
      assert Otel.Trace.current_span(ctx_with) == @valid_span_ctx
    end

    test "implicit context: round-trip via process Context" do
      assert Otel.Trace.current_span() == Otel.Trace.SpanContext.new()

      Otel.Trace.set_current_span(@valid_span_ctx)
      assert Otel.Trace.current_span() == @valid_span_ctx
    end
  end

  describe "make_current/1 + detach/1" do
    test "round-trip; nested attach/detach forms a LIFO stack; preserves unrelated keys" do
      key = Otel.Ctx.create_key(:unrelated)
      Otel.Ctx.set_value(key, :preserved)

      span_a = %Otel.Trace.SpanContext{trace_id: 0xAA, span_id: 0x01}
      span_b = %Otel.Trace.SpanContext{trace_id: 0xBB, span_id: 0x02}

      token_a = Otel.Trace.make_current(span_a)
      assert Otel.Trace.current_span() == span_a

      token_b = Otel.Trace.make_current(span_b)
      assert Otel.Trace.current_span() == span_b

      Otel.Trace.detach(token_b)
      assert Otel.Trace.current_span() == span_a

      Otel.Trace.detach(token_a)
      assert Otel.Trace.current_span() == Otel.Trace.SpanContext.new()

      assert Otel.Ctx.get_value(key) == :preserved
    end

    test "detach in `after` restores the prior context on exception" do
      assert_raise RuntimeError, "boom", fn ->
        token = Otel.Trace.make_current(@valid_span_ctx)

        try do
          raise "boom"
        after
          Otel.Trace.detach(token)
        end
      end

      assert Otel.Trace.current_span() == Otel.Trace.SpanContext.new()
    end
  end
end
