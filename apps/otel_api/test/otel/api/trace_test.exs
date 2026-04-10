defmodule Otel.API.TraceTest do
  use ExUnit.Case

  alias Otel.API.{Ctx, Trace}
  alias Otel.API.Trace.SpanContext

  @valid_span_ctx %SpanContext{
    trace_id: 0xFF000000000000000000000000000001,
    span_id: 0xFF00000000000001,
    trace_flags: 1
  }

  describe "get_tracer/1,2,3" do
    test "delegates to TracerProvider with name only" do
      {module, _} = Trace.get_tracer("my_lib")
      assert module == Otel.API.Trace.Noop
    end

    test "delegates to TracerProvider with name and version" do
      {module, _} = Trace.get_tracer("my_lib", "1.0.0")
      assert module == Otel.API.Trace.Noop
    end

    test "delegates to TracerProvider with name, version, schema_url" do
      {module, _} = Trace.get_tracer("my_lib", "1.0.0", "https://example.com")
      assert module == Otel.API.Trace.Noop
    end

    test "delegates to TracerProvider with attributes" do
      {module, _} = Trace.get_tracer("my_lib", "1.0.0", nil, %{key: "val"})
      assert module == Otel.API.Trace.Noop
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
end
