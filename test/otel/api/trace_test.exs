defmodule Otel.API.TraceTest do
  use ExUnit.Case, async: false

  @noop_tracer {Otel.API.Trace.Tracer.Noop, []}
  @valid_span_ctx %Otel.API.Trace.SpanContext{
    trace_id: 0xFF000000000000000000000000000001,
    span_id: 0xFF00000000000001,
    trace_flags: 1
  }

  setup do
    saved = :persistent_term.get({Otel.API.Trace.TracerProvider, :global}, nil)
    :persistent_term.erase({Otel.API.Trace.TracerProvider, :global})

    # Sweep tracer-cache keys created by the resolver under any
    # scope so the Noop fallback is observable.
    for {key, _} <- :persistent_term.get(),
        match?({{Otel.API.Trace.TracerProvider, :tracer}, _}, key) do
      :persistent_term.erase(key)
    end

    Otel.API.Ctx.attach(Otel.API.Ctx.new())

    on_exit(fn ->
      if saved,
        do: :persistent_term.put({Otel.API.Trace.TracerProvider, :global}, saved),
        else: :persistent_term.erase({Otel.API.Trace.TracerProvider, :global})
    end)
  end

  describe "get_tracer/1" do
    test "delegates to TracerProvider; returns the Noop tracer when no SDK installed" do
      scope = %Otel.API.InstrumentationScope{
        name: "my_lib",
        version: "1.0.0",
        schema_url: "https://example.com",
        attributes: %{"k" => "v"}
      }

      assert {Otel.API.Trace.Tracer.Noop, []} = Otel.API.Trace.get_tracer(scope)
    end
  end

  describe "current_span / set_current_span" do
    test "explicit context: round-trip; default Span when none set; immutable update" do
      ctx = Otel.API.Ctx.new()
      assert Otel.API.Trace.current_span(ctx) == %Otel.API.Trace.SpanContext{}

      ctx_with = Otel.API.Trace.set_current_span(ctx, @valid_span_ctx)

      # original ctx unchanged
      assert Otel.API.Trace.current_span(ctx) == %Otel.API.Trace.SpanContext{}
      assert Otel.API.Trace.current_span(ctx_with) == @valid_span_ctx
    end

    test "implicit context: round-trip via process Context" do
      assert Otel.API.Trace.current_span() == %Otel.API.Trace.SpanContext{}

      Otel.API.Trace.set_current_span(@valid_span_ctx)
      assert Otel.API.Trace.current_span() == @valid_span_ctx
    end
  end

  describe "start_span — Tracer dispatch (Noop)" do
    test "implicit context: returns a SpanContext but does NOT make it current" do
      span_ctx = Otel.API.Trace.start_span(@noop_tracer, "n", kind: :server)

      assert %Otel.API.Trace.SpanContext{} = span_ctx
      assert Otel.API.Trace.current_span() == %Otel.API.Trace.SpanContext{}
    end

    test "explicit context: Noop returns the parent when one is present, else default" do
      ctx_with_parent = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), @valid_span_ctx)

      assert Otel.API.Trace.start_span(ctx_with_parent, @noop_tracer, "child", []) ==
               @valid_span_ctx

      assert Otel.API.Trace.start_span(Otel.API.Ctx.new(), @noop_tracer, "root", []) ==
               %Otel.API.Trace.SpanContext{}
    end
  end

  describe "with_span/3,4,5 — lifecycle ownership" do
    test "runs the function, attaches the span, restores the prior span on success" do
      Otel.API.Trace.set_current_span(@valid_span_ctx)

      result =
        Otel.API.Trace.with_span(@noop_tracer, "test", [], fn span_ctx ->
          # Noop dispatches to the parent, so the active span is the parent.
          assert Otel.API.Trace.current_span() == span_ctx
          :ok
        end)

      assert result == :ok
      assert Otel.API.Trace.current_span() == @valid_span_ctx
    end

    # Spec trace/api.md L425-L431: ending the span lifecycle MUST
    # always run, even on exception/throw/exit. with_span uses
    # `try/after`-style detach plus exception forwarding.
    test "restores the prior context and re-raises across raise/throw/exit" do
      Otel.API.Trace.set_current_span(@valid_span_ctx)

      assert_raise RuntimeError, "boom", fn ->
        Otel.API.Trace.with_span(@noop_tracer, "n", [], fn _ -> raise "boom" end)
      end

      assert Otel.API.Trace.current_span() == @valid_span_ctx

      assert catch_throw(
               Otel.API.Trace.with_span(@noop_tracer, "n", [], fn _ -> throw(:bail) end)
             ) == :bail

      assert Otel.API.Trace.current_span() == @valid_span_ctx

      assert catch_exit(
               Otel.API.Trace.with_span(@noop_tracer, "n", [], fn _ -> exit(:shutdown) end)
             ) == :shutdown

      assert Otel.API.Trace.current_span() == @valid_span_ctx
    end

    test "explicit-context overload (with_span/5) uses the supplied context" do
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), @valid_span_ctx)

      result =
        Otel.API.Trace.with_span(ctx, @noop_tracer, "child", [], fn span_ctx ->
          assert span_ctx == @valid_span_ctx
          :from_explicit
        end)

      assert result == :from_explicit
    end

    test "with_span/3 — opts default to []" do
      assert Otel.API.Trace.with_span(@noop_tracer, "n", fn _ -> :ok end) == :ok
    end
  end

  describe "make_current/1 + detach/1" do
    test "round-trip; nested attach/detach forms a LIFO stack; preserves unrelated keys" do
      key = Otel.API.Ctx.create_key(:unrelated)
      Otel.API.Ctx.set_value(key, :preserved)

      span_a = %Otel.API.Trace.SpanContext{trace_id: 0xAA, span_id: 0x01}
      span_b = %Otel.API.Trace.SpanContext{trace_id: 0xBB, span_id: 0x02}

      token_a = Otel.API.Trace.make_current(span_a)
      assert Otel.API.Trace.current_span() == span_a

      token_b = Otel.API.Trace.make_current(span_b)
      assert Otel.API.Trace.current_span() == span_b

      Otel.API.Trace.detach(token_b)
      assert Otel.API.Trace.current_span() == span_a

      Otel.API.Trace.detach(token_a)
      assert Otel.API.Trace.current_span() == %Otel.API.Trace.SpanContext{}

      assert Otel.API.Ctx.get_value(key) == :preserved
    end

    test "detach in `after` restores the prior context on exception" do
      assert_raise RuntimeError, "boom", fn ->
        token = Otel.API.Trace.make_current(@valid_span_ctx)

        try do
          raise "boom"
        after
          Otel.API.Trace.detach(token)
        end
      end

      assert Otel.API.Trace.current_span() == %Otel.API.Trace.SpanContext{}
    end
  end
end
