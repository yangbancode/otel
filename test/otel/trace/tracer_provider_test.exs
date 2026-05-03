defmodule Otel.Trace.TracerProviderTest do
  use ExUnit.Case, async: false

  setup do
    Otel.TestSupport.restart_with()
    :ok
  end

  describe "init/0 + persistent_term state" do
    test "seeds resource only" do
      config = Otel.Trace.TracerProvider.config()
      assert %Otel.Resource{} = config.resource
      refute Map.has_key?(config, :span_limits)
    end

    test "resource/0 returns the seeded resource" do
      assert %Otel.Resource{} = Otel.Trace.TracerProvider.resource()
    end
  end

  describe "get_tracer/0" do
    test "returns a %Tracer{} struct carrying the hardcoded SDK scope and span_limits" do
      tracer = Otel.Trace.TracerProvider.get_tracer()

      assert %Otel.Trace.Tracer{} = tracer
      assert %Otel.InstrumentationScope{name: "otel"} = tracer.scope
      assert %Otel.Trace.SpanLimits{} = tracer.span_limits
    end
  end

  describe "introspection without provider state" do
    test "resource/0 falls back to Otel.Resource.default/0" do
      Otel.TestSupport.stop_all()

      assert %Otel.Resource{} = Otel.Trace.TracerProvider.resource()
      assert %{} = Otel.Trace.TracerProvider.config()
    end
  end
end
