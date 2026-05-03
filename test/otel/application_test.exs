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

      # All three Provider config/0 calls synthesize the resource
      # via `Otel.Resource.from_app_env/0` — no persistent_term.
      tracer_state = Otel.Trace.TracerProvider.config()
      assert %Otel.Resource{} = tracer_state.resource

      meter_state = Otel.Metrics.MeterProvider.config()
      assert %Otel.Resource{} = meter_state.resource
      assert meter_state.exemplar_filter == :trace_based
      assert meter_state.reader_id == :default_reader

      logger_state = Otel.Logs.LoggerProvider.config()
      assert %Otel.Resource{} = logger_state.resource
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
