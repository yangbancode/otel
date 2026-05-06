defmodule Otel.ApplicationTest do
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
    test "Otel.Resource.new/0 is the single resource source; meter_config carries it" do
      reboot()

      meter_state = Otel.Metrics.meter_config()
      assert %Otel.Resource{} = meter_state.resource
      assert meter_state.exemplar_filter == :trace_based

      # Pillars no longer expose `resource/0` wrappers — call
      # `Otel.Resource.new/0` directly for SDK introspection.
      assert %Otel.Resource{} = Otel.Resource.new()
    end

    test "supervised processor children are alive" do
      reboot()

      assert is_pid(Process.whereis(Otel.Trace.SpanExporter))
      assert is_pid(Process.whereis(Otel.Metrics.MetricExporter))
      assert is_pid(Process.whereis(Otel.Logs.LogRecordExporter))
      assert is_pid(Process.whereis(Otel.Trace.SpanStorage))
      assert is_pid(Process.whereis(Otel.Logs.LogRecordStorage))
    end
  end
end
