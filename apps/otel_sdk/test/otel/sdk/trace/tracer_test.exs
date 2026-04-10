defmodule Otel.SDK.Trace.TracerTest do
  use ExUnit.Case, async: true

  alias Otel.API.Ctx
  alias Otel.API.Trace.SpanContext
  alias Otel.SDK.Trace.Tracer

  describe "start_span/4" do
    test "returns SpanContext (stub)" do
      ctx = Ctx.new()
      tracer = {Tracer, %{config: %{}, scope: %{}}}
      result = Tracer.start_span(ctx, tracer, "test_span", [])
      assert %SpanContext{} = result
    end
  end

  describe "enabled?/2" do
    test "returns true" do
      tracer = {Tracer, %{}}
      assert Tracer.enabled?(tracer) == true
    end

    test "returns true with opts" do
      tracer = {Tracer, %{}}
      assert Tracer.enabled?(tracer, span_name: "test") == true
    end
  end
end
