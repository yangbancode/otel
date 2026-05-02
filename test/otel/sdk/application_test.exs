defmodule Otel.SDK.ApplicationTest do
  # Restarts :otel and mutates Application env — must not run async.
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:otel, :disabled)
      Application.delete_env(:otel, :propagators)
      reboot()
    end)

    :ok
  end

  defp reboot do
    Application.stop(:otel)
    Application.ensure_all_started(:otel)
  end

  describe "Provider boot" do
    test "providers boot from Otel.SDK.Config defaults" do
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

  describe "Propagator wiring" do
    test "hardcoded Composite[TraceContext, Baggage] is installed at boot" do
      reboot()

      assert {Otel.API.Propagator.TextMap.Composite,
              [Otel.API.Propagator.TextMap.TraceContext, Otel.API.Propagator.TextMap.Baggage]} =
               Otel.API.Propagator.TextMap.get_propagator()
    end

    # Spec sdk-environment-variables.md L113 — propagators MUST be
    # installed even when the SDK is disabled.
    test ":disabled true installs the propagator but not the provider GenServers" do
      Application.put_env(:otel, :disabled, true)
      reboot()

      assert {Otel.API.Propagator.TextMap.Composite, _} =
               Otel.API.Propagator.TextMap.get_propagator()

      refute Process.whereis(Otel.SDK.Trace.TracerProvider)
      refute Process.whereis(Otel.SDK.Metrics.MeterProvider)
      refute Process.whereis(Otel.SDK.Logs.LoggerProvider)
    end
  end
end
