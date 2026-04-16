#!/usr/bin/env elixir
# E2E test scenario: simulates a realistic microservice request flow
#
# Simulates: HTTP Gateway → Order Service → Payment Service → DB
# All 3 signals (Traces, Metrics, Logs) are emitted with deep nesting,
# cross-service correlation, error handling, and :logger integration.
#
# Usage: mix run test/e2e/scenario.exs
#
# Requires: OTel Collector running at http://localhost:4318
#   cd test/e2e && docker compose up -d

Application.ensure_all_started(:otel_sdk)
Application.ensure_all_started(:otel_exporter_otlp)
Application.ensure_all_started(:otel_logger_handler)

IO.puts("[e2e] Starting E2E scenario: Order Processing Pipeline")

# ============================================================
# SETUP: Providers and Exporters
# ============================================================

resource = Otel.SDK.Resource.create(%{
  "service.name" => "e2e-order-system",
  "service.version" => "1.0.0",
  "deployment.environment" => "e2e-test"
})

# --- Trace ---
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

# Tracers for different "services"
gateway_tracer = Otel.SDK.Trace.TracerProvider.get_tracer(trace_provider, "gateway", "1.0.0")
order_tracer = Otel.SDK.Trace.TracerProvider.get_tracer(trace_provider, "order-service", "2.1.0")
payment_tracer = Otel.SDK.Trace.TracerProvider.get_tracer(trace_provider, "payment-service", "1.3.0")
db_tracer = Otel.SDK.Trace.TracerProvider.get_tracer(trace_provider, "db-client", "0.5.0")

# --- Metrics ---
{:ok, metrics_provider} =
  Otel.SDK.Metrics.MeterProvider.start_link(config: %{})

gateway_meter = Otel.SDK.Metrics.MeterProvider.get_meter(metrics_provider, "gateway", "1.0.0")
order_meter = Otel.SDK.Metrics.MeterProvider.get_meter(metrics_provider, "order-service", "2.1.0")
payment_meter = Otel.SDK.Metrics.MeterProvider.get_meter(metrics_provider, "payment-service", "1.3.0")

Otel.API.Metrics.Meter.create_counter(gateway_meter, "http.server.requests", unit: "1")
Otel.API.Metrics.Meter.create_histogram(gateway_meter, "http.server.duration", unit: "ms")
Otel.API.Metrics.Meter.create_counter(order_meter, "orders.created", unit: "1")
Otel.API.Metrics.Meter.create_counter(order_meter, "orders.failed", unit: "1")
Otel.API.Metrics.Meter.create_histogram(payment_meter, "payment.processing_time", unit: "ms")
Otel.API.Metrics.Meter.create_gauge(payment_meter, "payment.gateway.balance", unit: "USD")

# --- Logs ---
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

# --- :logger handler (bridges Elixir Logger → OTel) ---
# Handler needs an SDK logger, not the API noop. Get it directly from the SDK provider.
{_mod, bridge_logger_config} = Otel.SDK.Logs.LoggerProvider.get_logger(log_provider, "elixir.logger", "1.0.0")
bridge_logger = {Otel.SDK.Logs.Logger, bridge_logger_config}

:logger.add_handler(:e2e_otel, Otel.Logger.Handler, %{
  config: %{otel_logger: bridge_logger}
})

# ============================================================
# SCENARIO 1: Successful Order (4-level deep trace)
# ============================================================

IO.puts("[e2e] Scenario 1: Successful order processing...")

Otel.API.Trace.with_span(gateway_tracer, "HTTP POST /api/orders", [kind: :server], fn _ctx ->
  span_ctx = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())
  Otel.API.Trace.Span.set_attribute(span_ctx, "http.method", "POST")
  Otel.API.Trace.Span.set_attribute(span_ctx, "http.url", "/api/orders")
  Otel.API.Trace.Span.set_attribute(span_ctx, "http.user_agent", "E2E-Test/1.0")

  Otel.API.Logs.Logger.emit(logger, %{
    severity_number: 9,
    severity_text: "INFO",
    body: "Incoming order request",
    attributes: %{component: "gateway", "http.method": "POST"}
  })

  Otel.API.Metrics.Meter.record(gateway_meter, "http.server.requests", 1, %{
    method: "POST",
    route: "/api/orders"
  })

  Process.sleep(5)

  # Level 2: Order Service
  Otel.API.Trace.with_span(order_tracer, "OrderService.create_order", [kind: :internal], fn _ctx ->
    order_span = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())
    Otel.API.Trace.Span.set_attribute(order_span, "order.id", "ORD-12345")
    Otel.API.Trace.Span.set_attribute(order_span, "order.total", 99.99)
    Otel.API.Trace.Span.set_attribute(order_span, "order.items_count", 3)
    Otel.API.Trace.Span.add_event(order_span, "order.validated", attributes: %{})

    Otel.API.Logs.Logger.emit(logger, %{
      severity_number: 9,
      severity_text: "INFO",
      body: "Creating order ORD-12345",
      attributes: %{component: "order-service", "order.id": "ORD-12345"}
    })

    Process.sleep(8)

    # Level 3: Payment Service
    Otel.API.Trace.with_span(payment_tracer, "PaymentService.charge", [kind: :client], fn _ctx ->
      pay_span = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())
      Otel.API.Trace.Span.set_attribute(pay_span, "payment.method", "credit_card")
      Otel.API.Trace.Span.set_attribute(pay_span, "payment.amount", 99.99)
      Otel.API.Trace.Span.set_attribute(pay_span, "payment.currency", "USD")

      Process.sleep(3)

      # Level 4: Database query
      Otel.API.Trace.with_span(db_tracer, "DB INSERT payments", [kind: :client], fn _ctx ->
        db_span = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())
        Otel.API.Trace.Span.set_attribute(db_span, "db.system", "postgresql")
        Otel.API.Trace.Span.set_attribute(db_span, "db.statement", "INSERT INTO payments ...")
        Otel.API.Trace.Span.set_attribute(db_span, "db.operation", "INSERT")

        Otel.API.Logs.Logger.emit(logger, %{
          severity_number: 5,
          severity_text: "DEBUG",
          body: "Executing INSERT INTO payments",
          attributes: %{component: "db-client", "db.system": "postgresql"}
        })

        Process.sleep(2)
      end)

      Otel.API.Trace.Span.add_event(pay_span, "payment.authorized")

      Otel.API.Metrics.Meter.record(payment_meter, "payment.processing_time", 15.3, %{
        method: "credit_card",
        status: "success"
      })
    end)

    # Level 3: DB write for order
    Otel.API.Trace.with_span(db_tracer, "DB INSERT orders", [kind: :client], fn _ctx ->
      db_span = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())
      Otel.API.Trace.Span.set_attribute(db_span, "db.system", "postgresql")
      Otel.API.Trace.Span.set_attribute(db_span, "db.statement", "INSERT INTO orders ...")
      Otel.API.Trace.Span.set_attribute(db_span, "db.operation", "INSERT")
      Process.sleep(1)
    end)

    Otel.API.Trace.Span.add_event(order_span, "order.created")
    Otel.API.Metrics.Meter.record(order_meter, "orders.created", 1, %{region: "us-east"})
  end)

  Otel.API.Trace.Span.set_attribute(span_ctx, "http.status_code", 201)
  Otel.API.Metrics.Meter.record(gateway_meter, "http.server.duration", 45.2, %{
    method: "POST",
    route: "/api/orders",
    status: "201"
  })
end)

Otel.SDK.Trace.TracerProvider.force_flush(trace_provider)
IO.puts("[e2e] Scenario 1 complete.")

# ============================================================
# SCENARIO 2: Failed Order (error propagation through spans)
# ============================================================

IO.puts("[e2e] Scenario 2: Failed order with error...")

Otel.API.Trace.with_span(gateway_tracer, "HTTP POST /api/orders", [kind: :server], fn _ctx ->
  span_ctx = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())
  Otel.API.Trace.Span.set_attribute(span_ctx, "http.method", "POST")
  Otel.API.Trace.Span.set_attribute(span_ctx, "http.url", "/api/orders")

  Process.sleep(3)

  # Level 2: Order Service
  Otel.API.Trace.with_span(order_tracer, "OrderService.create_order", [kind: :internal], fn _ctx ->
    order_span = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())
    Otel.API.Trace.Span.set_attribute(order_span, "order.id", "ORD-99999")

    Process.sleep(5)

    # Level 3: Payment fails
    Otel.API.Trace.with_span(payment_tracer, "PaymentService.charge", [kind: :client], fn _ctx ->
      pay_span = Otel.API.Trace.current_span(Otel.API.Ctx.get_current())
      Otel.API.Trace.Span.set_attribute(pay_span, "payment.method", "credit_card")
      Otel.API.Trace.Span.set_attribute(pay_span, "payment.amount", 5000.00)

      Process.sleep(10)

      # Payment declined — record exception
      exception = %RuntimeError{message: "Payment declined: insufficient funds"}
      Otel.API.Trace.Span.record_exception(pay_span, exception)
      Otel.API.Trace.Span.set_status(pay_span, :error, "Payment declined")

      Otel.API.Logs.Logger.emit(logger, %{
        severity_number: 17,
        severity_text: "ERROR",
        body: "Payment declined for order ORD-99999",
        exception: exception,
        attributes: %{
          component: "payment-service",
          "order.id": "ORD-99999",
          "payment.amount": 5000.00
        }
      })

      Otel.API.Metrics.Meter.record(payment_meter, "payment.processing_time", 120.5, %{
        method: "credit_card",
        status: "declined"
      })
    end)

    Otel.API.Trace.Span.set_status(order_span, :error, "Order creation failed")
    Otel.API.Metrics.Meter.record(order_meter, "orders.failed", 1, %{
      region: "us-east",
      reason: "payment_declined"
    })
  end)

  Otel.API.Trace.Span.set_attribute(span_ctx, "http.status_code", 402)
  Otel.API.Metrics.Meter.record(gateway_meter, "http.server.duration", 138.5, %{
    method: "POST",
    route: "/api/orders",
    status: "402"
  })
end)

Otel.SDK.Trace.TracerProvider.force_flush(trace_provider)
IO.puts("[e2e] Scenario 2 complete.")

# ============================================================
# SCENARIO 3: :logger bridge (Elixir Logger → OTel Logs)
# ============================================================

IO.puts("[e2e] Scenario 3: :logger bridge integration...")

Otel.API.Trace.with_span(gateway_tracer, "HTTP GET /api/health", [kind: :server], fn _ctx ->
  # These go through Erlang :logger → Otel.Logger.Handler → OTel Logs pipeline
  :logger.info("Health check passed", %{component: "gateway"})
  :logger.warning("Connection pool at 80% capacity", %{pool_size: 100, active: 80})
  :logger.error("Failed to connect to cache", %{cache_host: "redis-01"})
end)

Otel.SDK.Trace.TracerProvider.force_flush(trace_provider)
IO.puts("[e2e] Scenario 3 complete.")

# ============================================================
# SCENARIO 4: Observable instruments (async callbacks)
# ============================================================

IO.puts("[e2e] Scenario 4: Observable instruments...")

Otel.API.Metrics.Meter.create_observable_gauge(
  payment_meter,
  "payment.gateway.balance",
  fn _args -> [{25_432.50, %{gateway: "stripe"}}, {18_100.00, %{gateway: "paypal"}}] end,
  nil,
  unit: "USD",
  description: "Payment gateway balance"
)

Otel.API.Metrics.Meter.record(payment_meter, "payment.gateway.balance", 25_432.50, %{gateway: "stripe"})

IO.puts("[e2e] Scenario 4 complete.")

# ============================================================
# EXPORT METRICS
# ============================================================

IO.puts("[e2e] Exporting all metrics...")

for {_mod, meter_config} <- [gateway_meter, order_meter, payment_meter] do
  metrics = Otel.SDK.Metrics.MetricReader.collect(meter_config)

  if metrics != [] do
    {:ok, exporter_state} = Otel.Exporter.OTLP.Metrics.init(%{endpoint: "http://localhost:4318"})
    Otel.Exporter.OTLP.Metrics.export(metrics, exporter_state)
  end
end

IO.puts("[e2e] Metrics exported.")

# ============================================================
# CLEANUP
# ============================================================

IO.puts("[e2e] Shutting down...")

:logger.remove_handler(:e2e_otel)
Otel.SDK.Logs.LoggerProvider.shutdown(log_provider)
GenServer.stop(log_proc)
Otel.SDK.Metrics.MeterProvider.shutdown(metrics_provider)
Otel.SDK.Trace.TracerProvider.shutdown(trace_provider)
GenServer.stop(trace_proc)

IO.puts("[e2e] E2E scenario completed successfully.")
