defmodule Otel.SDK.ApplicationTest do
  # Restarts :otel_sdk and mutates env vars — must not run async.
  use ExUnit.Case, async: false

  @config_file_env "OTEL_CONFIG_FILE"
  @fixture Path.expand("../../fixtures/otel_config_console.yaml", __DIR__)

  setup do
    on_exit(fn ->
      System.delete_env(@config_file_env)
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
end
