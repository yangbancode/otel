defmodule Otel.SDK.ApplicationTest do
  # Restarts :otel — must not run async.
  use ExUnit.Case, async: false

  setup do
    on_exit(&reboot/0)
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
end
