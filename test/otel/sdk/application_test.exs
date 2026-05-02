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
    test "providers seed persistent_term state from Otel.SDK.Config defaults" do
      reboot()

      # TracerProvider state holds resource + span_limits + shut_down.
      tracer_state = Otel.Trace.TracerProvider.config()
      assert %Otel.Resource{} = tracer_state.resource
      assert %Otel.Trace.SpanLimits{} = tracer_state.span_limits
      assert tracer_state.shut_down == false

      # MeterProvider state holds resource + exemplar_filter + ETS refs.
      meter_state = Otel.Metrics.MeterProvider.config()
      assert %Otel.Resource{} = meter_state.resource
      assert meter_state.exemplar_filter == :trace_based

      # LoggerProvider state holds resource + log_record_limits.
      logger_state = Otel.Logs.LoggerProvider.config()
      assert %Otel.Resource{} = logger_state.resource
      assert %Otel.Logs.LogRecordLimits{} = logger_state.log_record_limits
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
