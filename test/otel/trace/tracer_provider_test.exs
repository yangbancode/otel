defmodule Otel.Trace.TracerProviderTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  setup do
    Otel.TestSupport.restart_with()
    :ok
  end

  describe "init/0 + persistent_term state" do
    test "seeds resource and span_limits" do
      config = Otel.Trace.TracerProvider.config()
      assert %Otel.Resource{} = config.resource
      assert %Otel.Trace.SpanLimits{} = config.span_limits
      assert config.shut_down == false
    end

    test "resource/0 returns the seeded resource" do
      assert %Otel.Resource{} = Otel.Trace.TracerProvider.resource()
    end
  end

  describe "get_tracer/1" do
    test "returns a %Tracer{} struct carrying scope and span_limits" do
      tracer =
        Otel.Trace.TracerProvider.get_tracer(%Otel.InstrumentationScope{
          name: "my_lib",
          version: "1.0.0",
          schema_url: "https://example.com"
        })

      assert %Otel.Trace.Tracer{} = tracer

      assert %Otel.InstrumentationScope{
               name: "my_lib",
               version: "1.0.0",
               schema_url: "https://example.com"
             } = tracer.scope

      assert %Otel.Trace.SpanLimits{} = tracer.span_limits
    end

    # Spec trace/sdk.md L125-L130 — invalid Tracer name SHOULD log a
    # warning, but the original value MUST be preserved.
    test "empty Tracer name → warns; valid name is silent" do
      log =
        capture_log(fn ->
          Otel.Trace.TracerProvider.get_tracer(%Otel.InstrumentationScope{name: ""})
        end)

      assert log =~ "invalid Tracer name"

      silent =
        capture_log(fn ->
          Otel.Trace.TracerProvider.get_tracer(%Otel.InstrumentationScope{name: "ok"})
        end)

      refute silent =~ "invalid Tracer name"
    end
  end

  describe "shutdown/1 + force_flush/1" do
    test "first shutdown :ok; subsequent → :already_shutdown" do
      assert :ok = Otel.Trace.TracerProvider.shutdown()
      assert {:error, :already_shutdown} = Otel.Trace.TracerProvider.shutdown()
      assert {:error, :already_shutdown} = Otel.Trace.TracerProvider.force_flush()
    end

    test "after shutdown, get_tracer returns a degenerate Tracer" do
      :ok = Otel.Trace.TracerProvider.shutdown()
      tracer = Otel.Trace.TracerProvider.get_tracer(%Otel.InstrumentationScope{name: "lib"})
      assert tracer == %Otel.Trace.Tracer{}
    end

    test "facades stay graceful when no provider state has been seeded" do
      Otel.TestSupport.stop_all()

      assert :ok = Otel.Trace.TracerProvider.force_flush()
      assert :ok = Otel.Trace.TracerProvider.shutdown()
      assert %Otel.Resource{} = Otel.Trace.TracerProvider.resource()
      assert %{} = Otel.Trace.TracerProvider.config()
    end
  end
end
