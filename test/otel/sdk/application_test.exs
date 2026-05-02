defmodule Otel.SDK.ApplicationTest do
  # Restarts :otel and mutates Application env — must not run async.
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
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
      # `Otel.Trace.Sampler` and ID generation to
      # `Otel.Trace.IdGenerator`).
      state = :sys.get_state(Otel.Trace.TracerProvider)

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
  end
end
