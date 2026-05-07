# E2E Test Scenarios

Tracking matrix for end-to-end tests against the local Grafana
LGTM stack. The infrastructure (case template, HTTP poller,
backend URL builders) lives under `test/e2e/support/`.

## Running

```bash
docker compose up -d
mix test --only e2e test/e2e/
```

## Smoke

Sanity net — minimal scenario per pillar, fast wire-format
regression detection across the SDK / collector boundary.

| Status | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| ✅ | 1 | Trace lands in Tempo with the configured name | `with_span/4` | Tempo: span name match |
| ✅ | 2 | Log lands in Loki with the rendered body | `Otel.Logs.emit/2` | Loki: body in lines |
| ✅ | 3 | Counter lands in Mimir with the right value | 2× `Counter.add(1)` | Mimir: cumulative value = 2.0 |

## Trace

| Status | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| ✅ | 1 | Single span (`with_span`) | `with_span/4` | Tempo: 1 span, name match |
| ✅ | 2 | Manual lifecycle | `start_span` + `end_span` | Tempo: 1 span |
| ✅ | 3 | `start_span` with explicit parent context | `start_span/4` (with ctx) | Tempo: parent_span_id matches passed ctx |
| ✅ | 4 | Initial attributes via opts | `with_span(opts: [attributes: %{...}])` | Tempo: span carries attrs |
| ✅ | 5 | Initial links via opts | `with_span(opts: [links: [...]])` | Tempo: links array |
| ✅ | 6 | `is_root: true` ignores parent | `with_span(opts: [is_root: true])` inside outer span | Tempo: `parent_span_id` empty |
| ✅ | 7 | `set_attribute/3` | mid-span mutation | Tempo: span carries attr |
| ✅ | 8 | `set_attributes/2` (bulk) | mid-span mutation | Tempo: all attrs |
| ✅ | 9 | Single event | `add_event/2` | Tempo: events array |
| ✅ | 10 | Multiple events preserve order | `add_event/2` × N | Tempo: events ordered |
| ✅ | 11 | Single link | `add_link/2` | Tempo: links array |
| ✅ | 12 | Multiple links preserve order | `add_link/2` × N | Tempo: links ordered |
| ✅ | 13 | Status `:ok` | `set_status/2` | Tempo: status.code = OK |
| ✅ | 14 | Status `:error` | `set_status/2` | Tempo: status.code = ERROR + message |
| ✅ | 15 | Update name | `update_name/2` | Tempo: updated name |
| ✅ | 16 | Span kinds — 5 variants iterated | `kind: :internal/:server/:client/:producer/:consumer` | Tempo: each kind matches |
| ✅ | 17 | Exception (`with_span` auto-records) | raise inside `with_span` | Tempo: exception event + Error status |
| ✅ | 18 | `record_exception/3` (manual) | `record_exception/3` | Tempo: exception event |
| ✅ | 19 | `record_exception/4` with override attrs | extra attrs override `exception.*` | Tempo: caller-supplied attrs win |
| ✅ | 20 | **Nested (parent-child)** | `with_span` inside `with_span` | Tempo: `parent_span_id` link |
| ✅ | 21 | **Sibling spans** | 2× `with_span` under one parent | Tempo: same `parent_span_id` |
| ✅ | 22 | **Deep nesting (5 levels)** | recursive `with_span` | Tempo: parent chain |
| ✅ | 23 | Tracestate propagates across nested spans | nested under parent w/ tracestate | Tempo: child carries parent tracestate |
| ✅ | 30 | Sampler — root span is sampled | emit without parent | Tempo: span present |
| ✅ | 31 | Sampler — child of sampled remote parent | inject sampled `traceparent`, then emit | Tempo: span present |
| ✅ | 32 | Sampler — child of not-sampled remote parent | inject not-sampled `traceparent`, then emit | Tempo: span absent |

## Trace — Telemetry tracer (`Otel.TelemetryTracer`)

| Status | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| ✅ | 1 | Single span — name from prefix, start+stop attrs merged | `:telemetry.span(prefix, %{a: 2, b: 3}, fn -> {5, %{result: 5}} end)` | Tempo: span name `"prefix.dotted"` + attrs `a/b/result` + `STATUS_CODE_OK` |
| ✅ | 2 | Nested span carries `parent_span_id` + same `trace_id` | nested `:telemetry.span` in same process | Tempo: inner `parentSpanId` = outer `spanId`, shared `traceId` |
| ✅ | 3 | Exception → ERROR status + recorded exception event | `raise` inside the span function | Tempo: `STATUS_CODE_ERROR`, `status.message`, `events[].name == "exception"` |
| ✅ | 4 | `metadata.span_kind` overrides default `:internal` | `:telemetry.span(prefix, %{span_kind: :client}, ...)` | Tempo: `kind = "SPAN_KIND_CLIENT"`, `span_kind` not leaked as attribute |
| ✅ | 5 | `:telemetry.span` inside `with_span/4` carries the outer span as parent | `Otel.Trace.with_span("outer", ..., fn _ -> :telemetry.span(...) end)` | Tempo: inner `parentSpanId` = outer `spanId`, shared `traceId` |
| ✅ | 6 | Multiple event prefixes registered to one tracer instance | `{Otel.TelemetryTracer, events: [a_prefix, b_prefix]}` + emit on both | Tempo: both spans land; sibling top-level spans get distinct `traceId` |

## Trace — `@span` decorator (`Otel.Decorator`)

| Status | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| ✅ | 1 | Decorated function — span name from event prefix + auto-captured args | `@span [:event] def f(a, b, c), do: ...` | Tempo: span name `"event.dotted"` + arg-named attributes (`a`, `b`, `c`) + `STATUS_CODE_OK` |

## Log — SDK API (`Otel.API.Logs.Logger.emit/2`)

| Status | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| ✅ | 1 | String body | `body: "msg"` | Loki: line match |
| ✅ | 2 | Map body | `body: %{...}` | Loki: structured fields |
| ✅ | 3 | Map body — nested map keys recursively stringified | `body: %{user: %{id: 42}}` | Loki: keys all `String.t()` |
| ✅ | 4 | Bytes body | `body: {:bytes, ...}` | Loki: structured-metadata query on `e2e.id` attribute (line filter would fail because the body is base64-encoded) |
| ✅ | 5 | All 8 severity levels | `severity_number: 5/9/10/13/17/18/19/21` | Loki: `severity_text` matches each |
| ✅ | 6 | `severity_number: 0` sentinel | default unspecified severity | Loki: `severity_number_unspecified` |
| ⚠️ | 7 | `event_name` field | `event_name: "..."` | LGTM Loki doesn't promote `event_name` to a queryable position; wire-format covered by `encoder_test.exs` |
| ✅ | 8 | `timestamp` vs `observed_timestamp` | omit timestamp → SDK fills observed | Loki: both fields present, distinct |
| ✅ | 9 | Custom attributes | `attributes: %{...}` | Loki: labels / fields |
| ✅ | 10 | **Trace context auto-propagation** | inside `with_span` | Loki: `trace_id` / `span_id` match |
| ✅ | 14 | Exception sidecar via SDK API | set `exception:` field on LogRecord | Loki: `exception.type` / `exception.message` |

## Log — `:logger` Handler bridge

| Status | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| ✅ | 1 | `Logger.info("msg")` baseline | string msg | Loki: line + `severity=info` |
| ✅ | 2 | All 8 levels iterated | `:emergency` through `:debug` | Loki: `severity_number` 21/19/18/17/13/10/9/5 |
| ✅ | 3 | Logger metadata — primitive | `Logger.info("...", k: v)` | Loki: attr `k=v` |
| ✅ | 4 | Report (map) | `Logger.info(%{k: v})` | Loki: structured |
| ✅ | 5 | Report (keyword) | `Logger.info(k: v, ...)` | Loki: structured |
| ✅ | 6 | `{format, args}` msg shape | `:logger.log(:info, ~c"~p", [v])` | Loki: formatted body |
| ✅ | 7 | `report_cb/1` callback | `meta: %{report_cb: cb1}` | Loki: callback output |
| ✅ | 8 | `report_cb/2` callback | `meta: %{report_cb: cb2}` | Loki: callback output |
| ✅ | 9 | Atom value coercion | `Logger.info(role: :admin)` | Loki: `"admin"` (no colon) |
| ✅ | 10 | Struct via `String.Chars` (Date) | `Logger.info(at: ~D[...])` | Loki: ISO string |
| ✅ | 11 | Tuple → `inspect` | `Logger.info(point: {1, 2})` | Loki: `"{1, 2}"` |
| ✅ | 12 | `crash_reason` → exception.* | `Logger.error(..., crash_reason: {e, st})` | Loki: `exception.type`, `exception.message`, `exception.stacktrace` |
| ✅ | 13 | Non-exception `crash_reason` ignored | `crash_reason: {:shutdown, _}` | Loki: no `exception.*` attrs |
| ✅ | 14 | `mfa` → `code.function.name` | `Logger.info(...)` (auto from compile) | Loki: `code.function.name` |
| ✅ | 15 | `file` → `code.file.path` | auto from compile | Loki: `code.file.path` |
| ✅ | 16 | `line` → `code.line.number` | auto from compile | Loki: `code.line.number` |
| ✅ | 17 | Malformed `mfa` silently skipped | `meta: %{mfa: :not_a_tuple}` | Loki: no `code.function.name`, no crash |
| ✅ | 18 | `domain` → `log.domain` | `meta: %{domain: [:a, :b]}` | Loki: array |
| ✅ | 19 | Reserved keys all filtered | `mfa, file, line, domain, crash_reason, time, report_cb, gl, pid` | Loki: none of these atoms appear |
| ✅ | 20 | **Trace context auto-propagation** | inside `with_span` | Loki: `trace_id` / `span_id` |

## Metrics

| Status | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| ✅ | 1 | Counter (single) | `Counter.add/3` | Mimir: `counter_total == 1` |
| ✅ | 2 | Counter cumulative | N adds | Mimir: `counter == N` |
| ✅ | 3 | UpDownCounter | `add 5`, `add -2` | Mimir: gauge `3` |
| ✅ | 4 | Histogram | `record × N` | Mimir: bucket counts, sum, count, **min/max** |
| ✅ | 5 | Histogram custom buckets | `advisory: [explicit_bucket_boundaries: ...]` | Mimir: `explicit_bounds` |
| ✅ | 8 | Gauge (sync) | `record/3` | Mimir: gauge value |
| ✅ | 16 | Cumulative temporality (default) | record over time | Mimir: monotonic accumulation |
| ⚠️ | 17 | Delta temporality | reader configured `:delta` | Unit-tested only — Mimir's OTLP receiver in LGTM 0.26.0 drops delta-temporality counters (delta-to-cumulative is opt-in, off by default), so an e2e test would have no signal beyond what `test/otel/sdk/metrics/temporality_test.exs` and `test/otel/otlp/encoder_test.exs` already cover. The setup_all-driven SDK restart that the e2e test would need also leaks delta config into other modules' tests |
| ✅ | 18 | Multi-dimensional attrs | same instrument, varying attrs | Mimir: multiple series |
| ✅ | 21 | Float vs int values mixed | record `1` then `1.5` on same series | Mimir: numerically correct |
| ⚠️ | 27 | Exemplar filter `:trace_based` (hardcoded) | sampled span only | Mimir: lands inside `with_span` (exemplar correlation in unit tests) |
| ⚠️ | 28 | Exemplar reservoir — `AlignedHistogramBucket` | histogram instrument | Mimir: histogram lands |
| ⚠️ | 29 | Exemplar reservoir — `SimpleFixedSize` | non-histogram instrument | Mimir: counter lands |
| ✅ | 30 | MetricExporter `force_flush` | call `force_flush` after record | Mimir: data visible immediately |
| ✅ | 31 | Case-insensitive duplicate registration | `create_counter("HTTP")` then `("http")` | Warns + returns first instrument |

## Metrics — Telemetry reporter (`Otel.TelemetryReporter`)

| Status | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| ✅ | 1 | `counter/2` → `Counter` | `:telemetry.execute` × N | Mimir: `_count_total` value matches event count |
| ✅ | 2 | `sum/2` → `UpDownCounter` (default, accepts negatives) | `delta` measurement, +/- | Mimir: numeric sum matches (5 + -2 = 3) |
| ✅ | 3 | `last_value/2` → `Gauge` | replace `value` measurement | Mimir: gauge value == last write |
| ✅ | 4 | `summary/2` → `Histogram` | `duration` measurement × N | Mimir: `_count` and `_sum` match |
| ✅ | 5 | `distribution/2` with `reporter_options: [buckets: …]` | custom bounds | Mimir: bucket counts match per `le` boundary |
| ✅ | 6 | Multi-dimensional `tags` | role / region | Mimir: one series per tag combination, each value verified |
| ✅ | 7 | Unit conversion `{:native, :millisecond}` | execute with `:native` time | Mimir: `_millisecond` suffix + value == 750 (post-conversion) |
| ✅ | 8 | `:keep` predicate filters events | meta-driven filter | Mimir: kept events count + dropped events absent (negative assertion) |
| ✅ | 9 | `sum/2` with `reporter_options: [monotonic: true]` → `Counter` | non-negative `bytes` measurement | Mimir: `_total` suffix + summed value (Counter wire shape) |
| ✅ | 10 | `:drop` predicate filters events (inverse of `:keep`) | drop `:test` env | Mimir: kept events count + dropped events absent (negative assertion) |
| ✅ | 11 | `:tag_values` transforms metadata before tagging | `meta.user.role` → flat tag | Mimir: `role` label value matches transformed metadata |
| ✅ | 12 | Function `:measurement` (1-arity) computes from measurements map | `fn meas -> meas[:in] + meas[:out] end` | Mimir: derived value `350.0` lands |
| ✅ | 13 | Byte unit conversion `{:byte, :kilobyte}` | bytes measurement | Mimir: `_kilobyte` suffix + decimal-converted value (4096 / 1000 = 4.096) |
| ✅ | 14 | Atom-only unit (no conversion) | `unit: :byte` | Mimir: `_byte` suffix + raw value `12345.0` lands |

## Propagator (cross-process trace continuation)

| Status | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| ✅ | 1 | TraceContext round-trip | `TextMap.inject/3` → carrier → `TextMap.extract/3` → child span with extracted ctx | Tempo: same `trace_id`, child `parent_span_id` = parent `span_id` |
| ✅ | 2 | Trace flags propagation (sampled bit) | sampled parent → inject → extract | Tempo: child also sampled / present |
| ✅ | 3 | Tracestate (vendor data) propagation | parent w/ tracestate → inject → extract | Tempo: child carries identical `tracestate` |
| ✅ | 4 | Baggage round-trip (manual span copy) | `Baggage.set_value/3` → inject → extract → copy to span attr | Tempo: span carries baggage value |
| ✅ | 5 | Composite (TraceContext + Baggage) | both propagators → inject → extract | Tempo: both trace ctx + baggage preserved |

## Resource / service identification

| Status | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| ✅ | 4 | `config :otel, :otp_app` → service.name + version | `config :otel, otp_app: :my_app` | Tempo: `service.name="my_app"`, `service.version=Application.spec(:my_app, :vsn)` |

## Cross-signal / Resource

| Status | # | Scenario | Backend assertion |
|---|---|---|---|
| ✅ | 1 | **Span-internal log carries trace_id** | `Tempo.trace_id == Loki.trace_id` |
| ✅ | 2 | **Metric exemplar carries trace_id** | `Mimir.exemplar.trace_id == Tempo.trace_id` |
| ✅ | 3 | Resource consistency (3 pillars) | All backends share `service.name` |
| ⚠️ | 4 | `InstrumentationScope` (Trace + Log) | hardcoded `scope.name = "otel"` carried through Tempo + Loki; Mimir doesn't promote OTLP scope to PromQL labels in LGTM 0.26.0 (lands-only) |

## Concurrency

The single-process happy-path scenarios in the per-signal
sections cover *what* the SDK exports. This section covers
*how* it behaves under load and async fan-out — concerns
that don't show up in spec-MUST checks but matter in
production. Scoped to scenarios that need no SDK reconfig
(every scenario runs in the standard `mix test --only e2e`
pass without touching `Application.put_env`).

| Status | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| ✅ | 1 | N=50 concurrent tasks each emit one span | `Task.async_stream` over 50 names | Tempo: every span name lands |
| ✅ | 2 | 1000 child spans under one parent (single trace) | `for _ <- 1..1000` of nested `with_span` | Tempo: trace contains all 1000 children within `force_flush` |
| ✅ | 3 | Three signals concurrent (trace + log + metric same scope) | `Task.async` × 3 emitting different signals | Tempo + Loki + Mimir each receive their record for the e2e_id |
| ✅ | 4 | Span context propagated across `Task.async_stream` | parent `with_span` wrapping async_stream that creates child spans | Tempo: every child carries the parent's `parent_span_id` |
