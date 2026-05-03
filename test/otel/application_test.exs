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
    test "providers seed persistent_term state from spec defaults + user :resource env" do
      reboot()

      # MeterProvider.config/0 synthesizes the resource via
      # `Otel.Resource.from_app_env/0` — no persistent_term.
      # (Tracer/LoggerProvider were dissolved into `Otel.Trace`
      # / `Otel.Logs`; resource is read on demand there too.)
      meter_state = Otel.Metrics.MeterProvider.config()
      assert %Otel.Resource{} = meter_state.resource
      assert meter_state.exemplar_filter == :trace_based
      assert meter_state.reader_id == :default_reader

      assert %Otel.Resource{} = Otel.Logs.resource()
      assert %Otel.Resource{} = Otel.Trace.resource()
    end

    test "supervised processor children are alive" do
      reboot()

      assert is_pid(Process.whereis(Otel.Trace.SpanProcessor))
      assert is_pid(Process.whereis(Otel.Metrics.MetricReader.PeriodicExporting))
      assert is_pid(Process.whereis(Otel.Logs.LogRecordProcessor))
      assert is_pid(Process.whereis(Otel.Trace.SpanStorage))
    end
  end
end
