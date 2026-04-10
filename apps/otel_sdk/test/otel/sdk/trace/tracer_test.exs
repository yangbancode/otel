defmodule Otel.SDK.Trace.TracerTest do
  use ExUnit.Case, async: true

  describe "start_span/4" do
    test "returns SpanContext (stub)" do
      ctx = Otel.API.Ctx.new()
      tracer = {Otel.SDK.Trace.Tracer, %{config: %{}, scope: %{}}}
      result = Otel.SDK.Trace.Tracer.start_span(ctx, tracer, "test_span", [])
      assert %Otel.API.Trace.SpanContext{} = result
    end
  end

  describe "enabled?/2" do
    test "returns true" do
      tracer = {Otel.SDK.Trace.Tracer, %{}}
      assert Otel.SDK.Trace.Tracer.enabled?(tracer) == true
    end

    test "returns true with opts" do
      tracer = {Otel.SDK.Trace.Tracer, %{}}
      assert Otel.SDK.Trace.Tracer.enabled?(tracer, span_name: "test") == true
    end
  end
end
