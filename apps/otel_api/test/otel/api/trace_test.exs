defmodule Otel.API.TraceTest do
  use ExUnit.Case

  @valid_span_ctx %Otel.API.Trace.SpanContext{
    trace_id: 0xFF000000000000000000000000000001,
    span_id: 0xFF00000000000001,
    trace_flags: 1
  }

  setup do
    :persistent_term.erase({Otel.API.Trace.TracerProvider, :global})

    for {key, _} <- :persistent_term.get(),
        is_tuple(key) and tuple_size(key) == 2 and
          elem(key, 0) == {Otel.API.Trace.TracerProvider, :tracer} do
      :persistent_term.erase(key)
    end

    :ok
  end

  describe "get_tracer/1" do
    test "delegates to TracerProvider with scope" do
      {module, _} = Otel.API.Trace.get_tracer(%Otel.API.InstrumentationScope{name: "my_lib"})
      assert module == Otel.API.Trace.Tracer.Noop
    end

    test "passes all scope fields through to TracerProvider" do
      scope = %Otel.API.InstrumentationScope{
        name: "my_lib",
        version: "1.0.0",
        schema_url: "https://example.com",
        attributes: %{"key" => "val"}
      }

      {module, _} = Otel.API.Trace.get_tracer(scope)
      assert module == Otel.API.Trace.Tracer.Noop
    end
  end

  describe "current_span/1 and set_current_span/2 (explicit context)" do
    test "returns invalid SpanContext when no span in context" do
      ctx = Otel.API.Ctx.new()
      assert Otel.API.Trace.current_span(ctx) == %Otel.API.Trace.SpanContext{}
    end

    test "returns span set in context" do
      ctx = Otel.API.Ctx.new()
      ctx = Otel.API.Trace.set_current_span(ctx, @valid_span_ctx)
      assert Otel.API.Trace.current_span(ctx) == @valid_span_ctx
    end

    test "set returns new context without modifying original" do
      ctx1 = Otel.API.Ctx.new()
      ctx2 = Otel.API.Trace.set_current_span(ctx1, @valid_span_ctx)
      assert Otel.API.Trace.current_span(ctx1) == %Otel.API.Trace.SpanContext{}
      assert Otel.API.Trace.current_span(ctx2) == @valid_span_ctx
    end
  end

  describe "current_span/0 and set_current_span/1 (implicit context)" do
    setup do
      Otel.API.Ctx.attach(Otel.API.Ctx.new())
      :ok
    end

    test "returns invalid SpanContext when no span set" do
      assert Otel.API.Trace.current_span() == %Otel.API.Trace.SpanContext{}
    end

    test "returns span set in process context" do
      Otel.API.Trace.set_current_span(@valid_span_ctx)
      assert Otel.API.Trace.current_span() == @valid_span_ctx
    end
  end

  describe "start_span/2,3 (implicit context)" do
    setup do
      Otel.API.Ctx.attach(Otel.API.Ctx.new())
      :ok
    end

    test "returns SpanContext from noop tracer" do
      tracer = {Otel.API.Trace.Tracer.Noop, []}
      span_ctx = Otel.API.Trace.start_span(tracer, "test_span")
      assert %Otel.API.Trace.SpanContext{} = span_ctx
    end

    test "does NOT set new span as current span" do
      tracer = {Otel.API.Trace.Tracer.Noop, []}
      _span_ctx = Otel.API.Trace.start_span(tracer, "test_span")
      assert Otel.API.Trace.current_span() == %Otel.API.Trace.SpanContext{}
    end

    test "accepts opts" do
      tracer = {Otel.API.Trace.Tracer.Noop, []}

      span_ctx =
        Otel.API.Trace.start_span(tracer, "test_span",
          kind: :server,
          attributes: %{"key" => "val"}
        )

      assert %Otel.API.Trace.SpanContext{} = span_ctx
    end
  end

  describe "start_span/4 (explicit context)" do
    test "uses provided context" do
      tracer = {Otel.API.Trace.Tracer.Noop, []}
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), @valid_span_ctx)
      span_ctx = Otel.API.Trace.start_span(ctx, tracer, "child_span", [])
      # noop returns parent when valid parent exists
      assert span_ctx == @valid_span_ctx
    end

    test "returns invalid SpanContext when no parent in context" do
      tracer = {Otel.API.Trace.Tracer.Noop, []}
      ctx = Otel.API.Ctx.new()
      span_ctx = Otel.API.Trace.start_span(ctx, tracer, "root_span", [])
      assert span_ctx == %Otel.API.Trace.SpanContext{}
    end
  end

  describe "with_span/3,4" do
    setup do
      Otel.API.Ctx.attach(Otel.API.Ctx.new())
      :ok
    end

    test "runs function and returns its result" do
      tracer = {Otel.API.Trace.Tracer.Noop, []}
      result = Otel.API.Trace.with_span(tracer, "test_span", [], fn _span_ctx -> :hello end)
      assert result == :hello
    end

    test "sets span as current during function execution" do
      Otel.API.Trace.set_current_span(@valid_span_ctx)
      tracer = {Otel.API.Trace.Tracer.Noop, []}

      Otel.API.Trace.with_span(tracer, "test_span", [], fn span_ctx ->
        # noop returns parent, so current span should be the parent
        assert Otel.API.Trace.current_span() == span_ctx
      end)
    end

    test "restores previous context after function returns" do
      Otel.API.Trace.set_current_span(@valid_span_ctx)
      tracer = {Otel.API.Trace.Tracer.Noop, []}

      Otel.API.Trace.with_span(tracer, "test_span", [], fn _span_ctx -> :ok end)

      assert Otel.API.Trace.current_span() == @valid_span_ctx
    end

    test "restores context and re-raises on exception" do
      Otel.API.Trace.set_current_span(@valid_span_ctx)
      tracer = {Otel.API.Trace.Tracer.Noop, []}

      assert_raise RuntimeError, "boom", fn ->
        Otel.API.Trace.with_span(tracer, "test_span", [], fn _span_ctx ->
          raise "boom"
        end)
      end

      assert Otel.API.Trace.current_span() == @valid_span_ctx
    end

    test "restores context and re-throws on throw" do
      Otel.API.Trace.set_current_span(@valid_span_ctx)
      tracer = {Otel.API.Trace.Tracer.Noop, []}

      assert catch_throw(
               Otel.API.Trace.with_span(tracer, "test_span", [], fn _span_ctx ->
                 throw(:bail)
               end)
             ) == :bail

      assert Otel.API.Trace.current_span() == @valid_span_ctx
    end

    test "restores context and re-exits on exit" do
      Otel.API.Trace.set_current_span(@valid_span_ctx)
      tracer = {Otel.API.Trace.Tracer.Noop, []}

      assert catch_exit(
               Otel.API.Trace.with_span(tracer, "test_span", [], fn _span_ctx ->
                 exit(:shutdown)
               end)
             ) == :shutdown

      assert Otel.API.Trace.current_span() == @valid_span_ctx
    end

    test "accepts opts with default empty list" do
      tracer = {Otel.API.Trace.Tracer.Noop, []}
      result = Otel.API.Trace.with_span(tracer, "test_span", fn _span_ctx -> :ok end)
      assert result == :ok
    end
  end

  describe "with_span/5 (explicit context)" do
    test "uses provided context" do
      tracer = {Otel.API.Trace.Tracer.Noop, []}
      ctx = Otel.API.Trace.set_current_span(Otel.API.Ctx.new(), @valid_span_ctx)

      result =
        Otel.API.Trace.with_span(ctx, tracer, "child_span", [], fn span_ctx ->
          assert span_ctx == @valid_span_ctx
          :from_explicit
        end)

      assert result == :from_explicit
    end
  end
end
