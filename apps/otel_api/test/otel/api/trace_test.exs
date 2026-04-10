defmodule Otel.API.TraceTest do
  use ExUnit.Case

  alias Otel.API.{Ctx, Trace}
  alias Otel.API.Trace.{SpanContext, Tracer}

  @valid_span_ctx %SpanContext{
    trace_id: 0xFF000000000000000000000000000001,
    span_id: 0xFF00000000000001,
    trace_flags: 1
  }

  describe "get_tracer/1,2,3" do
    test "delegates to TracerProvider with name only" do
      {module, _} = Trace.get_tracer("my_lib")
      assert module == Otel.API.Trace.Tracer.Noop
    end

    test "delegates to TracerProvider with name and version" do
      {module, _} = Trace.get_tracer("my_lib", "1.0.0")
      assert module == Otel.API.Trace.Tracer.Noop
    end

    test "delegates to TracerProvider with name, version, schema_url" do
      {module, _} = Trace.get_tracer("my_lib", "1.0.0", "https://example.com")
      assert module == Otel.API.Trace.Tracer.Noop
    end

    test "delegates to TracerProvider with attributes" do
      {module, _} = Trace.get_tracer("my_lib", "1.0.0", nil, %{key: "val"})
      assert module == Otel.API.Trace.Tracer.Noop
    end
  end

  describe "current_span/1 and set_current_span/2 (explicit context)" do
    test "returns invalid SpanContext when no span in context" do
      ctx = Ctx.new()
      assert Trace.current_span(ctx) == %SpanContext{}
    end

    test "returns span set in context" do
      ctx = Ctx.new()
      ctx = Trace.set_current_span(ctx, @valid_span_ctx)
      assert Trace.current_span(ctx) == @valid_span_ctx
    end

    test "set returns new context without modifying original" do
      ctx1 = Ctx.new()
      ctx2 = Trace.set_current_span(ctx1, @valid_span_ctx)
      assert Trace.current_span(ctx1) == %SpanContext{}
      assert Trace.current_span(ctx2) == @valid_span_ctx
    end
  end

  describe "current_span/0 and set_current_span/1 (implicit context)" do
    setup do
      Ctx.clear()
      :ok
    end

    test "returns invalid SpanContext when no span set" do
      assert Trace.current_span() == %SpanContext{}
    end

    test "returns span set in process context" do
      Trace.set_current_span(@valid_span_ctx)
      assert Trace.current_span() == @valid_span_ctx
    end
  end

  describe "start_span/2,3 (implicit context)" do
    setup do
      Ctx.clear()
      :ok
    end

    test "returns SpanContext from noop tracer" do
      tracer = {Tracer.Noop, []}
      span_ctx = Trace.start_span(tracer, "test_span")
      assert %SpanContext{} = span_ctx
    end

    test "does NOT set new span as current span" do
      tracer = {Tracer.Noop, []}
      _span_ctx = Trace.start_span(tracer, "test_span")
      assert Trace.current_span() == %SpanContext{}
    end

    test "accepts opts" do
      tracer = {Tracer.Noop, []}
      span_ctx = Trace.start_span(tracer, "test_span", kind: :server, attributes: %{key: "val"})
      assert %SpanContext{} = span_ctx
    end
  end

  describe "start_span/4 (explicit context)" do
    test "uses provided context" do
      tracer = {Tracer.Noop, []}
      ctx = Trace.set_current_span(Ctx.new(), @valid_span_ctx)
      span_ctx = Trace.start_span(ctx, tracer, "child_span", [])
      # noop returns parent when valid parent exists
      assert span_ctx == @valid_span_ctx
    end

    test "returns invalid SpanContext when no parent in context" do
      tracer = {Tracer.Noop, []}
      ctx = Ctx.new()
      span_ctx = Trace.start_span(ctx, tracer, "root_span", [])
      assert span_ctx == %SpanContext{}
    end
  end

  describe "with_span/3,4" do
    setup do
      Ctx.clear()
      :ok
    end

    test "runs function and returns its result" do
      tracer = {Tracer.Noop, []}
      result = Trace.with_span(tracer, "test_span", [], fn _span_ctx -> :hello end)
      assert result == :hello
    end

    test "sets span as current during function execution" do
      Trace.set_current_span(@valid_span_ctx)
      tracer = {Tracer.Noop, []}

      Trace.with_span(tracer, "test_span", [], fn span_ctx ->
        # noop returns parent, so current span should be the parent
        assert Trace.current_span() == span_ctx
      end)
    end

    test "restores previous context after function returns" do
      Trace.set_current_span(@valid_span_ctx)
      tracer = {Tracer.Noop, []}

      Trace.with_span(tracer, "test_span", [], fn _span_ctx -> :ok end)

      assert Trace.current_span() == @valid_span_ctx
    end

    test "restores context and re-raises on exception" do
      Trace.set_current_span(@valid_span_ctx)
      tracer = {Tracer.Noop, []}

      assert_raise RuntimeError, "boom", fn ->
        Trace.with_span(tracer, "test_span", [], fn _span_ctx ->
          raise "boom"
        end)
      end

      assert Trace.current_span() == @valid_span_ctx
    end

    test "restores context and re-throws on throw" do
      Trace.set_current_span(@valid_span_ctx)
      tracer = {Tracer.Noop, []}

      assert catch_throw(
               Trace.with_span(tracer, "test_span", [], fn _span_ctx ->
                 throw(:bail)
               end)
             ) == :bail

      assert Trace.current_span() == @valid_span_ctx
    end

    test "restores context and re-exits on exit" do
      Trace.set_current_span(@valid_span_ctx)
      tracer = {Tracer.Noop, []}

      assert catch_exit(
               Trace.with_span(tracer, "test_span", [], fn _span_ctx ->
                 exit(:shutdown)
               end)
             ) == :shutdown

      assert Trace.current_span() == @valid_span_ctx
    end

    test "accepts opts with default empty list" do
      tracer = {Tracer.Noop, []}
      result = Trace.with_span(tracer, "test_span", fn _span_ctx -> :ok end)
      assert result == :ok
    end
  end

  describe "with_span/5 (explicit context)" do
    test "uses provided context" do
      tracer = {Tracer.Noop, []}
      ctx = Trace.set_current_span(Ctx.new(), @valid_span_ctx)

      result =
        Trace.with_span(ctx, tracer, "child_span", [], fn span_ctx ->
          assert span_ctx == @valid_span_ctx
          :from_explicit
        end)

      assert result == :from_explicit
    end
  end
end
