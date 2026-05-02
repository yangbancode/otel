# E2E Test Scenarios

Tracking matrix for end-to-end tests against the local Grafana
LGTM stack. The infrastructure (case template, HTTP poller,
backend URL builders) lives under `test/e2e/support/`.

## Running

```bash
docker compose up -d
mix test --only e2e test/e2e/
```

## Trace

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[x]` | 1 | Single span (`with_span`) | `with_span/4` | Tempo: 1 span, name match |
| `[x]` | 2 | Manual lifecycle | `start_span` + `end_span` | Tempo: 1 span |
| `[x]` | 3 | `start_span` with explicit parent context | `start_span/4` (with ctx) | Tempo: parent_span_id matches passed ctx |
| `[x]` | 4 | Initial attributes via opts | `with_span(opts: [attributes: %{...}])` | Tempo: span carries attrs |
| `[x]` | 5 | Initial links via opts | `with_span(opts: [links: [...]])` | Tempo: links array |
| `[x]` | 6 | `is_root: true` ignores parent | `with_span(opts: [is_root: true])` inside outer span | Tempo: `parent_span_id` empty |
| `[x]` | 7 | `set_attribute/3` | mid-span mutation | Tempo: span carries attr |
| `[x]` | 8 | `set_attributes/2` (bulk) | mid-span mutation | Tempo: all attrs |
| `[x]` | 9 | Single event | `add_event/2` | Tempo: events array |
| `[x]` | 10 | Multiple events preserve order | `add_event/2` × N | Tempo: events ordered |
| `[x]` | 11 | Single link | `add_link/2` | Tempo: links array |
| `[x]` | 12 | Multiple links preserve order | `add_link/2` × N | Tempo: links ordered |
| `[x]` | 13 | Status `:ok` | `set_status/2` | Tempo: status.code = OK |
| `[x]` | 14 | Status `:error` | `set_status/2` | Tempo: status.code = ERROR + message |
| `[x]` | 15 | Update name | `update_name/2` | Tempo: updated name |
| `[x]` | 16 | Span kinds — 5 variants iterated | `kind: :internal/:server/:client/:producer/:consumer` | Tempo: each kind matches |
| `[x]` | 17 | Exception (`with_span` auto-records) | raise inside `with_span` | Tempo: exception event + Error status |
| `[x]` | 18 | `record_exception/3` (manual) | `record_exception/3` | Tempo: exception event |
| `[x]` | 19 | `record_exception/4` with override attrs | extra attrs override `exception.*` | Tempo: caller-supplied attrs win |
| `[x]` | 20 | **Nested (parent-child)** | `with_span` inside `with_span` | Tempo: `parent_span_id` link |
| `[x]` | 21 | **Sibling spans** | 2× `with_span` under one parent | Tempo: same `parent_span_id` |
| `[x]` | 22 | **Deep nesting (5 levels)** | recursive `with_span` | Tempo: parent chain |
| `[x]` | 23 | Tracestate propagates across nested spans | nested under parent w/ tracestate | Tempo: child carries parent tracestate |
| `[x]` | 24 | Span limits — `attribute_count_limit` | exceed limit | Tempo: `dropped_attributes_count > 0` |
| `[x]` | 25 | Span limits — `attribute_value_length_limit` truncation | long string attribute | Tempo: value truncated |
| `[x]` | 26 | Span limits — `event_count_limit` | exceed via `add_event` | Tempo: `dropped_events_count > 0` |
| `[x]` | 27 | Span limits — `link_count_limit` | exceed via `add_link` | Tempo: `dropped_links_count > 0` |
| `[x]` | 28 | Span limits — `attribute_per_event_limit` | event w/ excess attrs | Tempo: event `dropped_attributes_count` |
| `[x]` | 29 | Span limits — `attribute_per_link_limit` | link w/ excess attrs | Tempo: link `dropped_attributes_count` |
| `[x]` | 30 | Sampler — root span is sampled | emit without parent | Tempo: span present |
| `[x]` | 31 | Sampler — child of sampled remote parent | inject sampled `traceparent`, then emit | Tempo: span present |
| `[x]` | 32 | Sampler — child of not-sampled remote parent | inject not-sampled `traceparent`, then emit | Tempo: span absent |

## Log — SDK API (`Otel.API.Logs.Logger.emit/2`)

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[x]` | 1 | String body | `body: "msg"` | Loki: line match |
| `[x]` | 2 | Map body | `body: %{...}` | Loki: structured fields |
| `[x]` | 3 | Map body — nested map keys recursively stringified | `body: %{user: %{id: 42}}` | Loki: keys all `String.t()` |
| `[x]` | 4 | Bytes body | `body: {:bytes, ...}` | Loki: structured-metadata query on `e2e.id` attribute (line filter would fail because the body is base64-encoded) |
| `[x]` | 5 | All 8 severity levels | `severity_number: 5/9/10/13/17/18/19/21` | Loki: `severity_text` matches each |
| `[x]` | 6 | `severity_number: 0` sentinel | default unspecified severity | Loki: `severity_number_unspecified` |
| `[x]` | 7 | `event_name` field | `event_name: "..."` | Loki: event_name attribute |
| `[x]` | 8 | `timestamp` vs `observed_timestamp` | omit timestamp → SDK fills observed | Loki: both fields present, distinct |
| `[x]` | 9 | Custom attributes | `attributes: %{...}` | Loki: labels / fields |
| `[x]` | 10 | **Trace context auto-propagation** | inside `with_span` | Loki: `trace_id` / `span_id` match |
| `[x]` | 11 | LogRecord limits — `attribute_count_limit` | exceed attr count | Loki: `dropped_attributes_count` |
| `[x]` | 12 | LogRecord limits — `attribute_value_length_limit` truncation | long string attr | Loki: value truncated |
| `[x]` | 13 | Multi-logger (different scopes) | `get_logger(A)`, `get_logger(B)` | Loki: `scope_name` disambiguation |
| `[x]` | 14 | Exception sidecar via SDK API | set `exception:` field on LogRecord | Loki: `exception.type` / `exception.message` |

## Log — `:logger` Handler bridge

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[x]` | 1 | `Logger.info("msg")` baseline | string msg | Loki: line + `severity=info` |
| `[x]` | 2 | All 8 levels iterated | `:emergency` through `:debug` | Loki: `severity_number` 21/19/18/17/13/10/9/5 |
| `[x]` | 3 | Logger metadata — primitive | `Logger.info("...", k: v)` | Loki: attr `k=v` |
| `[x]` | 4 | Report (map) | `Logger.info(%{k: v})` | Loki: structured |
| `[x]` | 5 | Report (keyword) | `Logger.info(k: v, ...)` | Loki: structured |
| `[x]` | 6 | `{format, args}` msg shape | `:logger.log(:info, ~c"~p", [v])` | Loki: formatted body |
| `[x]` | 7 | `report_cb/1` callback | `meta: %{report_cb: cb1}` | Loki: callback output |
| `[x]` | 8 | `report_cb/2` callback | `meta: %{report_cb: cb2}` | Loki: callback output |
| `[x]` | 9 | Atom value coercion | `Logger.info(role: :admin)` | Loki: `"admin"` (no colon) |
| `[x]` | 10 | Struct via `String.Chars` (Date) | `Logger.info(at: ~D[...])` | Loki: ISO string |
| `[x]` | 11 | Tuple → `inspect` | `Logger.info(point: {1, 2})` | Loki: `"{1, 2}"` |
| `[x]` | 12 | `crash_reason` → exception.* | `Logger.error(..., crash_reason: {e, st})` | Loki: `exception.type`, `exception.message`, `exception.stacktrace` |
| `[x]` | 13 | Non-exception `crash_reason` ignored | `crash_reason: {:shutdown, _}` | Loki: no `exception.*` attrs |
| `[x]` | 14 | `mfa` → `code.function.name` | `Logger.info(...)` (auto from compile) | Loki: `code.function.name` |
| `[x]` | 15 | `file` → `code.file.path` | auto from compile | Loki: `code.file.path` |
| `[x]` | 16 | `line` → `code.line.number` | auto from compile | Loki: `code.line.number` |
| `[x]` | 17 | Malformed `mfa` silently skipped | `meta: %{mfa: :not_a_tuple}` | Loki: no `code.function.name`, no crash |
| `[x]` | 18 | `domain` → `log.domain` | `meta: %{domain: [:a, :b]}` | Loki: array |
| `[x]` | 19 | Reserved keys all filtered | `mfa, file, line, domain, crash_reason, time, report_cb, gl, pid` | Loki: none of these atoms appear |
| `[x]` | 20 | **Trace context auto-propagation** | inside `with_span` | Loki: `trace_id` / `span_id` |
| `[x]` | 21 | Scope config — 4 keys | `scope_name`, `scope_version`, `scope_schema_url`, `scope_attributes` | Loki: each value visible |

## Metrics

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[x]` | 1 | Counter (single) | `Counter.add/3` | Mimir: `counter_total == 1` |
| `[x]` | 2 | Counter cumulative | N adds | Mimir: `counter == N` |
| `[x]` | 3 | UpDownCounter | `add 5`, `add -2` | Mimir: gauge `3` |
| `[x]` | 4 | Histogram | `record × N` | Mimir: bucket counts, sum, count, **min/max** |
| `[x]` | 5 | Histogram custom buckets | `advisory: [explicit_bucket_boundaries: ...]` | Mimir: `explicit_bounds` |
| `[x]` | 8 | Gauge (sync) | `record/3` | Mimir: gauge value |
| `[x]` | 9 | ObservableCounter | callback returns `[%Measurement{}]` | Mimir: counter from callback |
| `[x]` | 10 | ObservableUpDownCounter | callback (multi-attr) | Mimir: multi-series |
| `[x]` | 11 | ObservableGauge | callback | Mimir: gauge from callback |
| `[x]` | 12 | `register_callback/5` (multi-instrument) | shared callback for several instruments | Mimir: each instrument fed |
| `[x]` | 13 | `unregister_callback/1` | unregister; collect again | Mimir: no further values |
| `[x]` | 16 | Cumulative temporality (default) | record over time | Mimir: monotonic accumulation |
| `[~]` | 17 | Delta temporality | reader configured `:delta` | Unit-tested only — Mimir's OTLP receiver in LGTM 0.26.0 drops delta-temporality counters (delta-to-cumulative is opt-in, off by default), so an e2e test would have no signal beyond what `test/otel/sdk/metrics/temporality_test.exs` and `test/otel/otlp/encoder_test.exs` already cover. The setup_all-driven SDK restart that the e2e test would need also leaks delta config into other modules' tests |
| `[x]` | 18 | Multi-dimensional attrs | same instrument, varying attrs | Mimir: multiple series |
| `[x]` | 21 | Float vs int values mixed | record `1` then `1.5` on same series | Mimir: numerically correct |
| `[~]` | 25 | Exemplar filter `:always_on` | sampling-mode reservoir | Mimir: lands (exemplar exposure config-dependent in LGTM 0.26.0) |
| `[~]` | 26 | Exemplar filter `:always_off` | reservoir is `Drop` | Mimir: lands (Drop is internal-only contract) |
| `[~]` | 27 | Exemplar filter `:trace_based` (default) | sampled span only | Mimir: lands inside `with_span` (exemplar correlation in unit tests) |
| `[~]` | 28 | Exemplar reservoir — `AlignedHistogramBucket` | histogram instrument | Mimir: histogram lands |
| `[~]` | 29 | Exemplar reservoir — `SimpleFixedSize` | non-histogram instrument | Mimir: counter lands |
| `[x]` | 30 | PeriodicExporting `force_flush` | call `force_flush` after record | Mimir: data visible immediately |
| `[x]` | 31 | Case-insensitive duplicate registration | `create_counter("HTTP")` then `("http")` | Warns + returns first instrument |

## Propagator (cross-process trace continuation)

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[x]` | 1 | TraceContext round-trip | `TextMap.inject/3` → carrier → `TextMap.extract/3` → child span with extracted ctx | Tempo: same `trace_id`, child `parent_span_id` = parent `span_id` |
| `[x]` | 2 | Trace flags propagation (sampled bit) | sampled parent → inject → extract | Tempo: child also sampled / present |
| `[x]` | 3 | Tracestate (vendor data) propagation | parent w/ tracestate → inject → extract | Tempo: child carries identical `tracestate` |
| `[x]` | 4 | Baggage round-trip (manual span copy) | `Baggage.set_value/3` → inject → extract → copy to span attr | Tempo: span carries baggage value |
| `[x]` | 5 | Composite (TraceContext + Baggage) | both propagators → inject → extract | Tempo: both trace ctx + baggage preserved |

## Resource / service identification

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[x]` | 4 | Mix Config `:resource` | `config :otel, trace: [resource: …]` | Tempo: resource overridden by Mix value |

## Global SDK control

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[x]` | 1 | `:disabled` Application env | `config :otel, disabled: true`; emit on all 3 pillars | All 3 backends: zero records for the e2e_id |
| `[x]` | 2 | Provider shutdown then emit | call `TracerProvider.shutdown/1` etc., emit afterward | No new records appear in backends |

## Cross-signal / Resource

| Done | # | Scenario | Backend assertion |
|---|---|---|---|
| `[x]` | 1 | **Span-internal log carries trace_id** | `Tempo.trace_id == Loki.trace_id` |
| `[x]` | 2 | **Metric exemplar carries trace_id** | `Mimir.exemplar.trace_id == Tempo.trace_id` |
| `[x]` | 3 | Resource consistency (3 pillars) | All backends share `service.name` |
| `[~]` | 4 | `InstrumentationScope` (Trace + Log) | `scope.name` carried through Tempo + Loki; Mimir doesn't promote OTLP scope to PromQL labels in LGTM 0.26.0 (lands-only) |

## Concurrency

The single-process happy-path scenarios in the per-signal
sections cover *what* the SDK exports. This section covers
*how* it behaves under load and async fan-out — concerns
that don't show up in spec-MUST checks but matter in
production. Scoped to scenarios that need no SDK reconfig
(every scenario runs in the standard `mix test --only e2e`
pass without touching `Application.put_env`).

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[x]` | 1 | N=50 concurrent tasks each emit one span | `Task.async_stream` over 50 names | Tempo: every span name lands |
| `[x]` | 2 | 1000 child spans under one parent (single trace) | `for _ <- 1..1000` of nested `with_span` | Tempo: trace contains all 1000 children within `force_flush` |
| `[x]` | 3 | Three signals concurrent (trace + log + metric same scope) | `Task.async` × 3 emitting different signals | Tempo + Loki + Mimir each receive their record for the e2e_id |
| `[x]` | 4 | Span context propagated across `Task.async_stream` | parent `with_span` wrapping async_stream that creates child spans | Tempo: every child carries the parent's `parent_span_id` |

## PR plan

| Phase | File | Scenarios |
|---|---|---|
| C-1 | `trace_test.exs` | 33 |
| C-2a | `log_sdk_test.exs` | 14 |
| C-2b | `log_handler_test.exs` | 21 |
| C-3a | `metrics_sync_test.exs` | ~10 (rows 1–5, 8, 16, 18, 21, 30, 31) |
| C-3b | `metrics_async_test.exs` | ~5 (rows 9–13) |
| C-3c | `metrics_exemplars_test.exs` | ~5 (rows 25–29) |
| C-4 | `propagator_test.exs` | 5 |
| C-5 | `resource_test.exs` | 4 |
| C-6 | `disabled_test.exs` | 2 |
| C-7 | `cross_signal_test.exs` | 4 |
| C-8 | `concurrency_test.exs` | 4 |

**Total: ~100 scenarios.** Tick `[x]` in the Done column as each
scenario lands. Phase C-3 splits into three focused PRs because the
Metrics surface is broad (sync vs observable vs exemplar); the
others stay one file each.

Out of e2e scope (covered by unit tests in `test/otel/...`):

* OTLP exporter knobs (compression, headers, retry, timeout) — exercised
  by `test/otel/otlp/{trace,metrics,logs}/*/http_test.exs` against a
  fake socket server.
* Concurrency / queue overflow / backpressure — exercised by
  `test/otel/sdk/trace/span_processor/batch_test.exs` and friends.
* Severity number → text mapping, attribute coercion rules, malformed
  metadata silent-skip — exercised by `test/otel/logger_handler_test.exs`.
