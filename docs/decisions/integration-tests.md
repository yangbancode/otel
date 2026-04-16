# Integration Tests

## Question

How to verify that all signals work correctly end-to-end? What cross-signal, lifecycle, configuration, and OTLP-level integration tests are needed beyond the existing unit tests?

## Decision

TBD — test list defined below; implementation follows after all signal phases are complete.

## Test Plan

### 1. Trace Pipeline (Provider → Span → Processor → Exporter)

- [ ] `TracerProvider.get_tracer` → `Trace.with_span` → span ends → `SimpleProcessor.on_end` → exporter receives span
- [ ] `TracerProvider.get_tracer` → `Trace.with_span` → span ends → `BatchProcessor` → batch threshold triggers export → exporter receives span
- [ ] `BatchProcessor` timer-based export delivers spans from `with_span`
- [ ] Sampled span reaches exporter; unsampled span does not
- [ ] Span with events, links, and attributes reaches exporter with all fields intact
- [ ] Nested spans (`with_span` inside `with_span`) produce correct parent-child relationship in exported spans
- [ ] `TracerProvider.shutdown` drains in-flight spans from `BatchProcessor` before completing
- [ ] `TracerProvider.force_flush` exports all pending spans from `BatchProcessor` synchronously
- [ ] After `TracerProvider.shutdown`, `get_tracer` returns noop tracer and spans are no-op

### 2. Metrics Pipeline (Provider → Meter → Record → Reader → Exporter)

- [ ] `MeterProvider.get_meter` → `create_counter` → `record` → `PeriodicExportingMetricReader.force_flush` → exporter receives metric with correct Sum datapoint
- [ ] Histogram end-to-end: create → record multiple values → flush → exporter receives HistogramDataPoint with correct bucket_counts, sum, count, min, max
- [ ] Gauge end-to-end: create → record → flush → exporter receives LastValue datapoint
- [ ] Observable counter with callback: register callback → reader collect triggers callback → exporter receives aggregated value
- [ ] Multi-reader: two readers on same provider → each receives independent metric stream
- [ ] View applied: provider with view that renames instrument → exporter receives renamed stream
- [ ] View with Drop aggregation → `enabled?` returns false, no datapoints exported
- [ ] Cardinality limit: record beyond limit → overflow attribute set appears in exported data
- [ ] Exemplar attached: record with active span → flush → exported datapoint has exemplar with trace_id/span_id
- [ ] Delta temporality: reader with delta config → second flush shows only delta values
- [ ] `MeterProvider.shutdown` triggers final export from all readers
- [ ] After `MeterProvider.shutdown`, `get_meter` returns noop meter

### 3. Logs Pipeline (Provider → Logger → Processor → Exporter)

- [ ] `LoggerProvider.get_logger` → `Logger.emit` → `SimpleProcessor` → exporter receives log record with all fields
- [ ] `LoggerProvider.get_logger` → `Logger.emit` → `BatchProcessor` → batch threshold triggers export
- [ ] `BatchProcessor` timer-based export delivers log records
- [ ] Log record with exception → exporter receives record with `exception.type` and `exception.message` attributes
- [ ] User attributes override exception-derived attributes
- [ ] `LogRecordLimits` applied: attributes beyond count limit are dropped, `dropped_attributes_count` is correct
- [ ] `LogRecordLimits` applied: string values exceeding length limit are truncated
- [ ] `observed_timestamp` is auto-set when not provided
- [ ] `LoggerProvider.shutdown` drains pending log records from `BatchProcessor`
- [ ] `LoggerProvider.force_flush` exports all pending log records synchronously
- [ ] After `LoggerProvider.shutdown`, `get_logger` returns noop logger
- [ ] `enabled?` returns false when no processors registered
- [ ] `enabled?` returns false when all processors return `enabled? = false`

### 4. Cross-Signal: Trace Context in Logs

- [ ] Start a span → attach to context → emit log record → exported log record has correct `trace_id` and `span_id` from the active span
- [ ] Nested spans: inner span active → emit log → log has inner span's `trace_id`/`span_id`
- [ ] No active span → emit log → log has `trace_id = 0` and `span_id = 0`
- [ ] Emit log inside `Trace.with_span` callback → log carries the span's trace context

### 5. Cross-Signal: Baggage

- [ ] Set baggage in context → start span → span can read baggage from context
- [ ] Set baggage → emit log → log record context carries baggage (verifiable by a custom processor)

### 6. OTLP Export (Encoder + HTTP Transport)

- [ ] OTLP Trace: encode spans → HTTP POST to stub server → decode protobuf → verify span fields match
- [ ] OTLP Metrics: encode metrics → HTTP POST to stub server → decode protobuf → verify metric type (Sum/Gauge/Histogram) and datapoint values
- [ ] OTLP Logs: encode log records → HTTP POST to stub server → decode protobuf → verify log record fields (after OTLP Logs Exporter is implemented)
- [ ] Gzip compression: export with `compression: :gzip` → stub server receives gzip body → decompress → valid protobuf
- [ ] Custom headers: export with `headers: %{"Authorization" => "Bearer token"}` → stub server receives header
- [ ] HTTPS endpoint: export to HTTPS stub server with self-signed cert → `ssl_options: [verify: :verify_none]` → success

### 7. Environment Variable Integration

- [ ] `OTEL_RESOURCE_ATTRIBUTES=service.name=my-app` → all signals' exported data has resource with `service.name = my-app`
- [ ] `OTEL_TRACES_SAMPLER=always_off` → no spans exported
- [ ] `OTEL_TRACES_SAMPLER=traceidratio` + `OTEL_TRACES_SAMPLER_ARG=0.0` → no spans exported
- [ ] `OTEL_BSP_SCHEDULE_DELAY=100` → trace BatchProcessor exports within ~100ms
- [ ] `OTEL_BLRP_SCHEDULE_DELAY=100` → logs BatchProcessor exports within ~100ms
- [ ] `OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT=5` → span with 10 attributes exports only 5
- [ ] `OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT=5` → log record with 10 attributes exports only 5
- [ ] `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:XXXX` → all OTLP exporters use this endpoint
- [ ] Signal-specific endpoint overrides general: `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` takes priority

### 8. Lifecycle & Supervision

- [ ] `Application.stop(:otel_sdk)` + `Application.ensure_all_started(:otel_sdk)` → clean restart, all providers operational
- [ ] Multiple `LoggerProvider` instances run independently (separate processors, separate resources)
- [ ] Multiple `MeterProvider` instances run independently
- [ ] Provider shutdown order: processor shutdown completes before provider GenServer exits
- [ ] Concurrent `force_flush` calls on same provider do not crash or deadlock
- [ ] Concurrent `emit` / `record` / `with_span` during `shutdown` do not crash

## Compliance

No direct spec compliance items — integration tests verify correct composition of individually-compliant components.
