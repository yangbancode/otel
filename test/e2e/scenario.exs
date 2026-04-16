#!/usr/bin/env elixir
# E2E test scenario: sends Traces, Metrics, and Logs to OTLP Collector
#
# Usage: mix run test/e2e/scenario.exs
#
# Requires: OTel Collector running at http://localhost:4318
#   cd test/e2e && docker compose up -d

Application.ensure_all_started(:otel_sdk)
Application.ensure_all_started(:otel_exporter_otlp)

IO.puts("[e2e] Starting E2E scenario...")

# ============================================================
# 1. TRACES
# ============================================================

IO.puts("[e2e] Setting up Traces...")

resource = Otel.SDK.Resource.create(%{"service.name" => "e2e-test-service"})

{:ok, trace_proc} =
  Otel.SDK.Trace.SimpleProcessor.start_link(%{
    name: :e2e_trace_proc,
    resource: resource,
    exporter: {Otel.Exporter.OTLP.Traces, %{endpoint: "http://localhost:4318"}}
  })

{:ok, trace_provider} =
  Otel.SDK.Trace.TracerProvider.start_link(
    config: %{
      processors: [{Otel.SDK.Trace.SimpleProcessor, %{reg_name: :e2e_trace_proc}}]
    }
  )

tracer = Otel.SDK.Trace.TracerProvider.get_tracer(trace_provider, "e2e_test", "1.0.0")

IO.puts("[e2e] Emitting trace span...")

Otel.API.Trace.with_span(tracer, "e2e-parent-span", fn _ctx ->
  Process.sleep(10)

  Otel.API.Trace.with_span(tracer, "e2e-child-span", fn _ctx ->
    span_ctx = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())
    Otel.API.Trace.Span.set_attribute(span_ctx, "http.method", "GET")
    Otel.API.Trace.Span.set_attribute(span_ctx, "http.status_code", 200)
    Otel.API.Trace.Span.add_event(span_ctx, "processing_complete")
    Process.sleep(5)
  end)
end)

Otel.SDK.Trace.TracerProvider.force_flush(trace_provider)
IO.puts("[e2e] Traces sent.")

# ============================================================
# 2. METRICS
# ============================================================

IO.puts("[e2e] Setting up Metrics...")

{:ok, metrics_provider} =
  Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

meter =
  Otel.SDK.Metrics.MeterProvider.get_meter(metrics_provider, "e2e_test", "1.0.0")

Otel.API.Metrics.Meter.create_counter(meter, "http.requests", unit: "1", description: "Total HTTP requests")
Otel.API.Metrics.Meter.create_histogram(meter, "http.duration", unit: "ms", description: "Request duration")
Otel.API.Metrics.Meter.create_gauge(meter, "system.cpu", unit: "%", description: "CPU usage")

IO.puts("[e2e] Recording metrics...")

for method <- ["GET", "POST", "GET", "GET", "POST"] do
  Otel.API.Metrics.Meter.record(meter, "http.requests", 1, %{method: method})
end

for duration <- [12.5, 45.0, 3.2, 150.7, 22.1] do
  Otel.API.Metrics.Meter.record(meter, "http.duration", duration, %{method: "GET"})
end

Otel.API.Metrics.Meter.record(meter, "system.cpu", 42.5, %{host: "web-01"})

# Collect and export metrics manually via OTLP
{_mod, meter_config} = meter
metrics = Otel.SDK.Metrics.MetricReader.collect(meter_config)

{:ok, exporter_state} = Otel.Exporter.OTLP.Metrics.init(%{endpoint: "http://localhost:4318"})
Otel.Exporter.OTLP.Metrics.export(metrics, exporter_state)

IO.puts("[e2e] Metrics sent.")

# ============================================================
# 3. LOGS
# ============================================================

IO.puts("[e2e] Setting up Logs...")

{:ok, log_proc} =
  Otel.SDK.Logs.SimpleProcessor.start_link(%{
    name: :e2e_log_proc,
    exporter: {Otel.Exporter.OTLP.Logs, %{endpoint: "http://localhost:4318"}}
  })

{:ok, log_provider} =
  Otel.SDK.Logs.LoggerProvider.start_link(
    config: %{
      processors: [{Otel.SDK.Logs.SimpleProcessor, %{reg_name: :e2e_log_proc}}]
    }
  )

{_mod, logger_config} = Otel.SDK.Logs.LoggerProvider.get_logger(log_provider, "e2e_test", "1.0.0")
logger = {Otel.SDK.Logs.Logger, logger_config}

IO.puts("[e2e] Emitting log records...")

Otel.API.Logs.Logger.emit(logger, %{
  severity_number: 9,
  severity_text: "INFO",
  body: "E2E test started",
  attributes: %{component: "e2e_test"}
})

Otel.API.Logs.Logger.emit(logger, %{
  severity_number: 17,
  severity_text: "ERROR",
  body: "Simulated error in E2E test",
  attributes: %{error_code: "E001", component: "e2e_test"}
})

# Log with trace context (emit inside a span)
Otel.API.Trace.with_span(tracer, "e2e-logged-span", fn _ctx ->
  Otel.API.Logs.Logger.emit(logger, %{
    severity_number: 9,
    severity_text: "INFO",
    body: "Log with trace context",
    attributes: %{component: "e2e_test"}
  })
end)

Otel.SDK.Trace.TracerProvider.force_flush(trace_provider)
IO.puts("[e2e] Logs sent.")

# ============================================================
# 4. CLEANUP
# ============================================================

IO.puts("[e2e] Shutting down...")

Otel.SDK.Logs.LoggerProvider.shutdown(log_provider)
GenServer.stop(log_proc)
Otel.SDK.Metrics.MeterProvider.shutdown(metrics_provider)
Otel.SDK.Trace.TracerProvider.shutdown(trace_provider)
GenServer.stop(trace_proc)

IO.puts("[e2e] E2E scenario completed successfully.")
