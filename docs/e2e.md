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
| `[ ]` | 1 | Single span (`with_span`) | `with_span/4` | Tempo: 1 span, name match |
| `[ ]` | 2 | Manual lifecycle | `start_span` + `end_span` | Tempo: 1 span |
| `[ ]` | 3 | Attribute (single) | `set_attribute/3` | Tempo: span carries attr |
| `[ ]` | 4 | Attributes (bulk) | `set_attributes/2` | Tempo: span carries all attrs |
| `[ ]` | 5 | Event | `add_event/2` | Tempo: events array |
| `[ ]` | 6 | Link | `add_link/2` | Tempo: links array |
| `[ ]` | 7 | Status (Ok / Error / Unset) | `set_status/2` | Tempo: status.code |
| `[ ]` | 8 | Update name | `update_name/2` | Tempo: updated name |
| `[ ]` | 9 | Span kinds (5 variants) | `kind: :server / …` | Tempo: kind matches |
| `[ ]` | 10 | Exception (`with_span` auto) | raise inside `with_span` | Tempo: exception event + Error status |
| `[ ]` | 11 | Exception (manual) | `record_exception/3` | Tempo: exception event |
| `[ ]` | 12 | **Nested (parent-child)** | `with_span` inside `with_span` | Tempo: parent_span_id link |
| `[ ]` | 13 | **Sibling spans** | 2× `with_span` under one parent | Tempo: same parent_span_id |
| `[ ]` | 14 | **Deep nesting (5 levels)** | recursive `with_span` | Tempo: parent chain |
| `[ ]` | 15 | Span limits | exceed `attribute_count_limit` | Tempo: `dropped_attributes_count > 0` |
| `[ ]` | 16 | Sampler `always_off` | configured then emit | Tempo: span absent |

## Log — SDK API (`Otel.API.Logs.Logger.emit/2`)

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[ ]` | 1 | String body | `body: "msg"` | Loki: line match |
| `[ ]` | 2 | Map body | `body: %{...}` | Loki: structured fields |
| `[ ]` | 3 | Bytes body | `body: {:bytes, ...}` | Loki: bytes encoding |
| `[ ]` | 4 | Severity levels (8) | `severity_number: 5..21` | Loki: `severity_text` |
| `[ ]` | 5 | Custom attributes | `attributes: %{...}` | Loki: labels / fields |
| `[ ]` | 6 | **Trace context auto-propagation** | inside `with_span` | Loki: `trace_id` / `span_id` match |
| `[ ]` | 7 | LogRecord limits | exceed attr count | Loki: `dropped_attributes_count` |
| `[ ]` | 8 | Multi-logger (different scopes) | `get_logger(A)`, `get_logger(B)` | Loki: `scope_name` disambiguation |

## Log — `:logger` Handler bridge

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[ ]` | 1 | `Logger.info("msg")` baseline | string msg | Loki: line + `severity=info` |
| `[ ]` | 2 | **All 8 levels** | `:emergency`–`:debug` | Loki: `severity_text` mapping |
| `[ ]` | 3 | Logger metadata | `Logger.info("...", k: v)` | Loki: attr `k=v` |
| `[ ]` | 4 | Report (map) | `Logger.info(%{k: v})` | Loki: structured |
| `[ ]` | 5 | Report (keyword) | `Logger.info(k: v, ...)` | Loki: structured |
| `[ ]` | 6 | `report_cb/1` callback | `meta: %{report_cb: cb1}` | Loki: callback output |
| `[ ]` | 7 | `report_cb/2` callback | `meta: %{report_cb: cb2}` | Loki: callback output |
| `[ ]` | 8 | `crash_reason` → exception | `Logger.error(..., crash_reason: ...)` | Loki: `exception.*` attrs |
| `[ ]` | 9 | mfa / file / line → semconv | metadata auto-injected | Loki: `code.function.name` etc. |
| `[ ]` | 10 | `domain` → `log.domain` | `Logger.info(..., domain: [:a, :b])` | Loki: array |
| `[ ]` | 11 | Reserved keys filtered | `gl, time, report_cb` | Loki: keys absent |
| `[ ]` | 12 | **Trace context auto-propagation** | inside `with_span` | Loki: `trace_id` match |
| `[ ]` | 13 | Scope config | handler config's 4 `scope_*` keys | Loki: `scope_name` etc. |
| `[ ]` | 14 | Struct via `String.Chars` (Date) | `Logger.info(at: ~D[...])` | Loki: ISO string |
| `[ ]` | 15 | Tuple → `inspect` | `Logger.info(point: {1, 2})` | Loki: string |

## Metrics

| Done | # | Scenario | API | Backend assertion |
|---|---|---|---|---|
| `[ ]` | 1 | Counter (single) | `Counter.add/3` | Mimir: `counter_total == 1` |
| `[ ]` | 2 | Counter (cumulative) | `N` adds | Mimir: `counter == N` |
| `[ ]` | 3 | UpDownCounter | `add 5`, `add -2` | Mimir: `3` |
| `[ ]` | 4 | Histogram | `record × N` | Mimir: bucket counts, sum, count |
| `[ ]` | 5 | Histogram custom buckets | `advisory: [explicit_bucket_boundaries: ...]` | Mimir: `explicit_bounds` |
| `[ ]` | 6 | Gauge (sync) | `record/3` | Mimir: gauge value |
| `[ ]` | 7 | ObservableCounter | callback | Mimir: counter from callback |
| `[ ]` | 8 | ObservableUpDownCounter | callback (multi-attr) | Mimir: multi-series |
| `[ ]` | 9 | ObservableGauge | callback | Mimir: gauge from callback |
| `[ ]` | 10 | Multi-dimensional attrs | same instrument, varying attrs | Mimir: multiple series |
| `[ ]` | 11 | Cardinality overflow | exceed default limit | Mimir: `otel.metric.overflow=true` |
| `[ ]` | 12 | Float vs int values | record both | Mimir: exact values |

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
| C-1 | `trace_test.exs` | 16 |
| C-2a | `log_sdk_test.exs` | 8 |
| C-2b | `log_handler_test.exs` | 15 |
| C-3 | `metrics_test.exs` | 12 |
| C-4 | `cross_signal_test.exs` | 4 |

**Total: ~55 scenarios.** Tick `[x]` in the Done column as each
scenario lands.
