defmodule Otel.SDK.ApplicationTest do
  # Restarts :otel and mutates env vars — must not run async.
  use ExUnit.Case, async: false

  @config_file_env "OTEL_CONFIG_FILE"
  @fixture Path.expand("../../fixtures/otel_config_console.yaml", __DIR__)

  setup do
    on_exit(fn ->
      System.delete_env(@config_file_env)
      System.delete_env("OTEL_SDK_DISABLED")
      System.delete_env("OTEL_PROPAGATORS")
      Application.delete_env(:otel, :propagators)
      reboot()
    end)

    :ok
  end

  defp reboot do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)
  end

  describe "OTEL_CONFIG_FILE routing" do
    test "unset / empty string → providers boot from env-var defaults" do
      for value <- [nil, ""] do
        if value,
          do: System.put_env(@config_file_env, value),
          else: System.delete_env(@config_file_env)

        reboot()

        # Tracer state has the three default keys (no :sampler or
        # :id_generator — sampling is hardcoded to
        # `Otel.SDK.Trace.Sampler` and ID generation to
        # `Otel.SDK.Trace.IdGenerator`).
        state = :sys.get_state(Otel.SDK.Trace.TracerProvider)

        for key <- [:processors, :resource, :span_limits],
            do: assert(Map.has_key?(state, key))
      end
    end

    test "set → providers boot from the YAML pipeline (Substitution → Parser → Schema → Composer)" do
      System.put_env(@config_file_env, @fixture)
      reboot()

      tracer_state = :sys.get_state(Otel.SDK.Trace.TracerProvider)

      # Fixture pins console exporter only and a distinctive
      # resource service.name.
      assert tracer_state.resource.attributes["service.name"] == "otel_config_wiring_test"

      logs_state = :sys.get_state(Otel.SDK.Logs.LoggerProvider)
      assert [%{module: Otel.SDK.Logs.LogRecordProcessor}] = logs_state.processors
    end
  end

  describe "Propagator wiring" do
    test "hardcoded Composite[TraceContext, Baggage] is installed at boot" do
      reboot()

      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               Otel.API.Propagator.TextMap.get_propagator()
    end

    # Spec sdk-environment-variables.md L113 — propagators MUST be
    # installed even when OTEL_SDK_DISABLED disables provider boot.
    test "OTEL_SDK_DISABLED=true installs the propagator but not the provider GenServers" do
      System.put_env("OTEL_SDK_DISABLED", "true")
      reboot()

      assert {Otel.API.Propagator.TextMap.Composite, _} =
               Otel.API.Propagator.TextMap.get_propagator()

      refute Process.whereis(Otel.SDK.Trace.TracerProvider)
      refute Process.whereis(Otel.SDK.Metrics.MeterProvider)
      refute Process.whereis(Otel.SDK.Logs.LoggerProvider)
    end
  end
end
