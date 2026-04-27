defmodule Otel.SDK.ApplicationTest do
  # Restarts :otel_sdk and mutates env vars — must not run async.
  use ExUnit.Case, async: false

  @config_file_env "OTEL_CONFIG_FILE"
  @fixture Path.expand("../../fixtures/otel_config_console.yaml", __DIR__)

  setup do
    on_exit(fn ->
      System.delete_env(@config_file_env)
      System.delete_env("OTEL_SDK_DISABLED")
      System.delete_env("OTEL_PROPAGATORS")
      Application.delete_env(:otel_sdk, :propagators)
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)
    end)

    :ok
  end

  describe "OTEL_CONFIG_FILE routing" do
    test "OTEL_CONFIG_FILE unset → providers receive env-var-derived configs" do
      System.delete_env(@config_file_env)
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      # Default env-var path uses parent_based(always_on) sampler
      # (spec L143 default + Otel.SDK.Config.trace defaults).
      tracer_state = :sys.get_state(Otel.SDK.Trace.TracerProvider)
      assert {Otel.SDK.Trace.Sampler.ParentBased, _} = tracer_state.sampler
    end

    test "OTEL_CONFIG_FILE set + :otel_config loaded → providers receive YAML-derived configs" do
      System.put_env(@config_file_env, @fixture)
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      # Fixture pins sampler to always_off, console exporter only.
      tracer_state = :sys.get_state(Otel.SDK.Trace.TracerProvider)
      assert {Otel.SDK.Trace.Sampler.AlwaysOff, _} = tracer_state.sampler

      # Fixture's resource block sets a distinctive service.name —
      # confirms the resource flowed through Substitution → Parser
      # → Schema → Composer → start_link config.
      assert tracer_state.resource.attributes["service.name"] ==
               "otel_config_wiring_test"

      # Logs provider should also have a single Simple processor
      # with a console exporter per the fixture.
      logs_state = :sys.get_state(Otel.SDK.Logs.LoggerProvider)
      assert [%{module: Otel.SDK.Logs.LogRecordProcessor.Simple}] = logs_state.processors
    end
  end

  describe "OTEL_PROPAGATORS wiring" do
    test "default — global propagator is Composite of TraceContext + Baggage" do
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               Otel.API.Propagator.TextMap.get_propagator()
    end

    test "OTEL_PROPAGATORS=tracecontext installs single propagator" do
      System.put_env("OTEL_PROPAGATORS", "tracecontext")
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      assert Otel.API.Propagator.TextMap.get_propagator() ==
               Otel.API.Propagator.TextMap.TraceContext
    end

    test "OTEL_SDK_DISABLED=true still installs propagators (spec L113)" do
      System.put_env("OTEL_SDK_DISABLED", "true")
      System.put_env("OTEL_PROPAGATORS", "baggage")
      Application.stop(:otel_sdk)
      Application.ensure_all_started(:otel_sdk)

      # Propagator IS set even though providers are not.
      assert Otel.API.Propagator.TextMap.get_propagator() ==
               Otel.API.Propagator.TextMap.Baggage

      # No supervised provider GenServers — supervisor children list is empty.
      refute Process.whereis(Otel.SDK.Trace.TracerProvider)
      refute Process.whereis(Otel.SDK.Metrics.MeterProvider)
      refute Process.whereis(Otel.SDK.Logs.LoggerProvider)
    end
  end
end
