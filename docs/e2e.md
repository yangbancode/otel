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
| `[ ]` | 30 | Sampler `always_on` | configured then emit | Tempo: span present |
| `[ ]` | 31 | Sampler `always_off` | configured then emit | Tempo: span absent |
| `[ ]` | 32 | Sampler `parentbased_always_on` | inherit parent decision | Tempo: span present iff parent sampled |
| `[ ]` | 33 | Sampler `traceidratio` (e.g. 1.0) | configured then emit | Tempo: span present |

## Log — SDK API (`Otel.API.Logs.Logger.emit/2`)

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[ ]` | 1 | String body | `body: "msg"` | Loki: line match |
| `[ ]` | 2 | Map body | `body: %{...}` | Loki: structured fields |
| `[ ]` | 3 | Map body — nested map keys recursively stringified | `body: %{user: %{id: 42}}` | Loki: keys all `String.t()` |
| `[ ]` | 4 | Bytes body | `body: {:bytes, ...}` | Loki: bytes encoding |
| `[ ]` | 5 | All 8 severity levels | `severity_number: 5/9/10/13/17/18/19/21` | Loki: `severity_text` matches each |
| `[ ]` | 6 | `severity_number: 0` sentinel | default unspecified severity | Loki: `severity_number_unspecified` |
| `[ ]` | 7 | `event_name` field | `event_name: "..."` | Loki: event_name attribute |
| `[ ]` | 8 | `timestamp` vs `observed_timestamp` | omit timestamp → SDK fills observed | Loki: both fields present, distinct |
| `[ ]` | 9 | Custom attributes | `attributes: %{...}` | Loki: labels / fields |
| `[ ]` | 10 | **Trace context auto-propagation** | inside `with_span` | Loki: `trace_id` / `span_id` match |
| `[ ]` | 11 | LogRecord limits — `attribute_count_limit` | exceed attr count | Loki: `dropped_attributes_count` |
| `[ ]` | 12 | LogRecord limits — `attribute_value_length_limit` truncation | long string attr | Loki: value truncated |
| `[ ]` | 13 | Multi-logger (different scopes) | `get_logger(A)`, `get_logger(B)` | Loki: `scope_name` disambiguation |
| `[ ]` | 14 | Exception sidecar via SDK API | set `exception:` field on LogRecord | Loki: `exception.type` / `exception.message` |

## Log — `:logger` Handler bridge

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[ ]` | 1 | `Logger.info("msg")` baseline | string msg | Loki: line + `severity=info` |
| `[ ]` | 2 | All 8 levels iterated | `:emergency` through `:debug` | Loki: `severity_number` 21/19/18/17/13/10/9/5 |
| `[ ]` | 3 | Logger metadata — primitive | `Logger.info("...", k: v)` | Loki: attr `k=v` |
| `[ ]` | 4 | Report (map) | `Logger.info(%{k: v})` | Loki: structured |
| `[ ]` | 5 | Report (keyword) | `Logger.info(k: v, ...)` | Loki: structured |
| `[ ]` | 6 | `{format, args}` msg shape | `:logger.log(:info, ~c"~p", [v])` | Loki: formatted body |
| `[ ]` | 7 | `report_cb/1` callback | `meta: %{report_cb: cb1}` | Loki: callback output |
| `[ ]` | 8 | `report_cb/2` callback | `meta: %{report_cb: cb2}` | Loki: callback output |
| `[ ]` | 9 | Atom value coercion | `Logger.info(role: :admin)` | Loki: `"admin"` (no colon) |
| `[ ]` | 10 | Struct via `String.Chars` (Date) | `Logger.info(at: ~D[...])` | Loki: ISO string |
| `[ ]` | 11 | Tuple → `inspect` | `Logger.info(point: {1, 2})` | Loki: `"{1, 2}"` |
| `[ ]` | 12 | `crash_reason` → exception.* | `Logger.error(..., crash_reason: {e, st})` | Loki: `exception.type`, `exception.message`, `exception.stacktrace` |
| `[ ]` | 13 | Non-exception `crash_reason` ignored | `crash_reason: {:shutdown, _}` | Loki: no `exception.*` attrs |
| `[ ]` | 14 | `mfa` → `code.function.name` | `Logger.info(...)` (auto from compile) | Loki: `code.function.name` |
| `[ ]` | 15 | `file` → `code.file.path` | auto from compile | Loki: `code.file.path` |
| `[ ]` | 16 | `line` → `code.line.number` | auto from compile | Loki: `code.line.number` |
| `[ ]` | 17 | Malformed `mfa` silently skipped | `meta: %{mfa: :not_a_tuple}` | Loki: no `code.function.name`, no crash |
| `[ ]` | 18 | `domain` → `log.domain` | `meta: %{domain: [:a, :b]}` | Loki: array |
| `[ ]` | 19 | Reserved keys all filtered | `mfa, file, line, domain, crash_reason, time, report_cb, gl, pid` | Loki: none of these atoms appear |
| `[ ]` | 20 | **Trace context auto-propagation** | inside `with_span` | Loki: `trace_id` / `span_id` |
| `[ ]` | 21 | Scope config — 4 keys | `scope_name`, `scope_version`, `scope_schema_url`, `scope_attributes` | Loki: each value visible |

## Metrics

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[ ]` | 1 | Counter (single) | `Counter.add/3` | Mimir: `counter_total == 1` |
| `[ ]` | 2 | Counter cumulative | N adds | Mimir: `counter == N` |
| `[ ]` | 3 | UpDownCounter | `add 5`, `add -2` | Mimir: gauge `3` |
| `[ ]` | 4 | Histogram | `record × N` | Mimir: bucket counts, sum, count, **min/max** |
| `[ ]` | 5 | Histogram custom buckets | `advisory: [explicit_bucket_boundaries: ...]` | Mimir: `explicit_bounds` |
| `[ ]` | 6 | Histogram `record_min_max: false` | View opt | Mimir: `min`/`max` absent |
| `[ ]` | 7 | Base2ExponentialBucketHistogram | `aggregation: :base2_exponential_bucket_histogram` | Mimir: positive/negative bucket counts, scale, zero_count |
| `[ ]` | 8 | Gauge (sync) | `record/3` | Mimir: gauge value |
| `[ ]` | 9 | ObservableCounter | callback returns `[%Measurement{}]` | Mimir: counter from callback |
| `[ ]` | 10 | ObservableUpDownCounter | callback (multi-attr) | Mimir: multi-series |
| `[ ]` | 11 | ObservableGauge | callback | Mimir: gauge from callback |
| `[ ]` | 12 | `register_callback/5` (multi-instrument) | shared callback for several instruments | Mimir: each instrument fed |
| `[ ]` | 13 | `unregister_callback/1` | unregister; collect again | Mimir: no further values |
| `[ ]` | 14 | Drop aggregation | View w/ `aggregation: :drop` | Mimir: no series for that instrument |
| `[ ]` | 15 | `Meter.enabled?/2` gating | when matching streams all `:drop` | Returns `false`; `add` is a no-op |
| `[ ]` | 16 | Cumulative temporality (default) | record over time | Mimir: monotonic accumulation |
| `[ ]` | 17 | Delta temporality | reader configured `:delta` | Mimir: per-window delta values |
| `[ ]` | 18 | Multi-dimensional attrs | same instrument, varying attrs | Mimir: multiple series |
| `[ ]` | 19 | Cardinality overflow (sync) | exceed View `aggregation_cardinality_limit` | Mimir: `otel.metric.overflow=true` |
| `[ ]` | 20 | Cardinality first-observed (async) | observable callback emits N+1 attrs | Mimir: first-N pinned across delta resets |
| `[ ]` | 21 | Float vs int values mixed | record `1` then `1.5` on same series | Mimir: numerically correct |
| `[ ]` | 22 | View — rename instrument | `criteria: %{name: ...}, config: %{name: "renamed"}` | Mimir: series under new name |
| `[ ]` | 23 | View — attribute include filter | `config: %{attribute_keys: [...]}` | Mimir: only listed labels |
| `[ ]` | 24 | View — override aggregation | `config: %{aggregation: :explicit_bucket_histogram}` for a Counter | Mimir: histogram series |
| `[ ]` | 25 | Exemplar filter `:always_on` | sampling-mode reservoir | Mimir: every measurement attaches exemplar |
| `[ ]` | 26 | Exemplar filter `:always_off` | reservoir is `Drop` | Mimir: no exemplars |
| `[ ]` | 27 | Exemplar filter `:trace_based` (default) | sampled span only | Mimir: exemplar present iff span sampled |
| `[ ]` | 28 | Exemplar reservoir — `AlignedHistogramBucket` | histogram instrument | Mimir: per-bucket exemplar |
| `[ ]` | 29 | Exemplar reservoir — `SimpleFixedSize` | non-histogram instrument | Mimir: ≤ N exemplars (size cap) |
| `[ ]` | 30 | PeriodicExporting `force_flush` | call `force_flush` after record | Mimir: data visible immediately |
| `[ ]` | 31 | Case-insensitive duplicate registration | `create_counter("HTTP")` then `("http")` | Warns + returns first instrument |

## Propagator (cross-process trace continuation)

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[ ]` | 1 | TraceContext round-trip | `TextMap.inject/3` → carrier → `TextMap.extract/3` → child span with extracted ctx | Tempo: same `trace_id`, child `parent_span_id` = parent `span_id` |
| `[ ]` | 2 | Trace flags propagation (sampled bit) | sampled parent → inject → extract | Tempo: child also sampled / present |
| `[ ]` | 3 | Tracestate (vendor data) propagation | parent w/ tracestate → inject → extract | Tempo: child carries identical `tracestate` |
| `[ ]` | 4 | Baggage round-trip (manual span copy) | `Baggage.set_value/3` → inject → extract → copy to span attr | Tempo: span carries baggage value |
| `[ ]` | 5 | Composite (TraceContext + Baggage) | both propagators → inject → extract | Tempo: both trace ctx + baggage preserved |

## Resource / service identification

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[ ]` | 1 | `OTEL_SERVICE_NAME` env var | set then SDK restart | All 3 backends: `service.name` matches env value |
| `[ ]` | 2 | `OTEL_RESOURCE_ATTRIBUTES` env var | set `deployment.environment=test,…` | Tempo / Loki / Mimir: resource carries those attrs |
| `[ ]` | 3 | `OTEL_SERVICE_NAME` precedence | both env vars set with conflicting `service.name` | `service.name` matches `OTEL_SERVICE_NAME` (spec MUST) |
| `[ ]` | 4 | Mix Config `:resource` | `config :otel, trace: [resource: …]` | Tempo: resource overridden by Mix value |

## Global SDK control

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[ ]` | 1 | `OTEL_SDK_DISABLED=true` | restart with env set; emit on all 3 pillars | All 3 backends: zero records for the e2e_id |
| `[ ]` | 2 | Provider shutdown then emit | call `TracerProvider.shutdown/1` etc., emit afterward | No new records appear in backends |

## Cross-signal / Resource

| Done | # | Scenario | Backend assertion |
|---|---|---|---|
| `[ ]` | 1 | **Span-internal log carries trace_id** | `Tempo.trace_id == Loki.trace_id` |
| `[ ]` | 2 | **Metric exemplar carries trace_id** | `Mimir.exemplar.trace_id == Tempo.trace_id` |
| `[ ]` | 3 | Resource consistency (3 pillars) | All backends share `service.name` |
| `[ ]` | 4 | `InstrumentationScope` (3 pillars) | `scope.name` correctly mapped |

## PR plan

| Phase | File | Scenarios |
|---|---|---|
| C-1 | `trace_test.exs` | 33 |
| C-2a | `log_sdk_test.exs` | 14 |
| C-2b | `log_handler_test.exs` | 21 |
| C-3a | `metrics_sync_test.exs` | ~15 (rows 1–11, 14–17, 21) |
| C-3b | `metrics_async_test.exs` | ~6 (rows 9–13, 20) |
| C-3c | `metrics_view_test.exs` | ~9 (rows 22–24, 25–29, 30–31) |
| C-4 | `propagator_test.exs` | 5 |
| C-5 | `resource_test.exs` | 4 |
| C-6 | `disabled_test.exs` | 2 |
| C-7 | `cross_signal_test.exs` | 4 |

**Total: ~113 scenarios.** Tick `[x]` in the Done column as each
scenario lands. Phase C-3 splits into three focused PRs because the
Metrics surface is broad (sync vs observable vs View / exemplar /
reader knobs); the others stay one file each.

Out of e2e scope (covered by unit tests in `test/otel/...`):

* OTLP exporter knobs (compression, headers, retry, timeout) — exercised
  by `test/otel/otlp/{trace,metrics,logs}/*/http_test.exs` against a
  fake socket server.
* `OTEL_CONFIG_FILE` declarative YAML loading / substitution / schema
  validation — exercised by `test/otel/configuration/*_test.exs`.
* Concurrency / queue overflow / backpressure — exercised by
  `test/otel/sdk/trace/span_processor/batch_test.exs` and friends.
* Severity number → text mapping, attribute coercion rules, malformed
  metadata silent-skip — exercised by `test/otel/logger_handler_test.exs`.
