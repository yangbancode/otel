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

      # TracerProvider state holds resource only — span_limits is
      # compile-time literal on the Tracer struct.
      tracer_state = Otel.Trace.TracerProvider.config()
      assert %Otel.Resource{} = tracer_state.resource

      # MeterProvider state holds resource + ETS refs +
      # base/reader meter configs (which carry exemplar_filter
      # and temporality_mapping as compile-time literals).
      meter_state = Otel.Metrics.MeterProvider.config()
      assert %Otel.Resource{} = meter_state.resource
      assert meter_state.base_meter_config.exemplar_filter == :trace_based

      # LoggerProvider state holds resource only — log_record_limits
      # is stamped on the Logger struct from compile-time literal.
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
