# Configuration

The SDK resolves configuration from three layers, highest precedence first:

1. **Application env** — `Application.get_env(:otel, …)`, usually set in `config/runtime.exs`.
2. **OS environment** — spec-blessed `OTEL_*` variables.
3. **Built-in defaults** — match the OpenTelemetry spec defaults.

Mix freely between layers. The `OTEL_CONFIG_FILE` declarative-YAML path,
when set, overrides everything else (handled by `Otel.Configuration`).

## via `config/runtime.exs`

```elixir
import Config

config :otel,
  trace: [
    sampler: :parentbased_always_on,
    exporter: :otlp,
    processor: :batch,
    span_limits: %{attribute_count_limit: 256}
  ],
  metrics: [
    exporter: :otlp,
    reader_config: %{export_interval_ms: 30_000}
  ],
  logs: [
    exporter: :otlp,
    processor: :batch
  ],
  propagators: [:tracecontext, :baggage]
```

## via `OTEL_*` environment

```bash
export OTEL_TRACES_SAMPLER=parentbased_always_on
export OTEL_TRACES_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp
export OTEL_METRIC_EXPORT_INTERVAL=30000
export OTEL_LOGS_EXPORTER=otlp
export OTEL_PROPAGATORS=tracecontext,baggage
```

## Selectors — accepted forms

Every `exporter:` / `processor:` / `sampler:` / propagator entry accepts:

- a built-in **shortcut atom** from the tables below,
- a direct **module atom** (e.g. `MyApp.CustomExporter`) — normalized to `{Module, %{}}`, or
- a **`{module, %{...}}` tuple** for a custom config.

## Trace pillar

| Option | `config :otel, trace:` | `OTEL_*` | Accepted values | Default |
|---|---|---|---|---|
| Sampler | `sampler:` | `OTEL_TRACES_SAMPLER` | `:always_on` / `:always_off` / `:parentbased_always_on` / `:parentbased_always_off` / `:traceidratio` / `:parentbased_traceidratio` / `{:traceidratio, 0.5}` / `{Module, opts}` | `:parentbased_always_on` |
| Sampler arg | (in tuple form above) | `OTEL_TRACES_SAMPLER_ARG` | float in `0.0..1.0` | `1.0` |
| Exporter | `exporter:` | `OTEL_TRACES_EXPORTER` | `:otlp` / `:console` / `:none` / `Module` / `{Module, %{}}` | `:otlp` |
| Processor | `processor:` | — | `:batch` / `:simple` / `Module` | `:batch` |
| Explicit processor list | `processors:` | — | list of `{module, config}` | inferred |
| Batch schedule delay | `processor_config: %{scheduled_delay_ms: _}` | `OTEL_BSP_SCHEDULE_DELAY` | non-negative integer (ms) | `5000` |
| Batch export timeout | `processor_config: %{export_timeout_ms: _}` | `OTEL_BSP_EXPORT_TIMEOUT` | integer (ms); `0` ⇒ `:infinity` | `30000` |
| Batch queue size | `processor_config: %{max_queue_size: _}` | `OTEL_BSP_MAX_QUEUE_SIZE` | integer | `2048` |
| Batch export batch size | `processor_config: %{max_export_batch_size: _}` | `OTEL_BSP_MAX_EXPORT_BATCH_SIZE` | integer | `512` |
| Span attribute count | `span_limits: %{attribute_count_limit: _}` | `OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT` (fallback `OTEL_ATTRIBUTE_COUNT_LIMIT`) | integer | `128` |
| Span attribute value length | `span_limits: %{attribute_value_length_limit: _}` | `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT` (fallback `OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT`) | integer or `:infinity` | `:infinity` |
| Event count | `span_limits: %{event_count_limit: _}` | `OTEL_SPAN_EVENT_COUNT_LIMIT` | integer | `128` |
| Link count | `span_limits: %{link_count_limit: _}` | `OTEL_SPAN_LINK_COUNT_LIMIT` | integer | `128` |
| Per-event attribute count | `span_limits: %{attribute_per_event_limit: _}` | `OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT` | integer | `128` |
| Per-link attribute count | `span_limits: %{attribute_per_link_limit: _}` | `OTEL_LINK_ATTRIBUTE_COUNT_LIMIT` | integer | `128` |
| Resource | `resource:` | `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_SERVICE_NAME` | `%Otel.SDK.Resource{}` | SDK identity attributes |
| ID generator | `id_generator:` | — | module | `Otel.SDK.Trace.IdGenerator.Default` |

## Metrics pillar

| Option | `config :otel, metrics:` | `OTEL_*` | Accepted values | Default |
|---|---|---|---|---|
| Exporter | `exporter:` | `OTEL_METRICS_EXPORTER` | `:otlp` / `:console` / `:none` / `Module` / `{Module, %{}}` | `:otlp` |
| Explicit reader list | `readers:` | — | list of `{module, config}` | inferred from `exporter:` |
| Reader export interval | `reader_config: %{export_interval_ms: _}` | `OTEL_METRIC_EXPORT_INTERVAL` | non-negative integer (ms) | `60000` |
| Reader export timeout | `reader_config: %{export_timeout_ms: _}` | `OTEL_METRIC_EXPORT_TIMEOUT` | integer (ms); `0` ⇒ `:infinity` | `30000` |
| Exemplar filter | `exemplar_filter:` | `OTEL_METRICS_EXEMPLAR_FILTER` | `:always_on` / `:always_off` / `:trace_based` | `:trace_based` |
| Views | `views:` | — | list of `Otel.SDK.Metrics.View.t()` | `[]` |
| Resource | `resource:` | `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_SERVICE_NAME` | `%Otel.SDK.Resource{}` | SDK identity attributes |

## Logs pillar

| Option | `config :otel, logs:` | `OTEL_*` | Accepted values | Default |
|---|---|---|---|---|
| Exporter | `exporter:` | `OTEL_LOGS_EXPORTER` | `:otlp` / `:console` / `:none` / `Module` / `{Module, %{}}` | `:otlp` |
| Processor | `processor:` | — | `:batch` / `:simple` / `Module` | `:batch` |
| Explicit processor list | `processors:` | — | list of `{module, config}` | inferred |
| Batch schedule delay | `processor_config: %{scheduled_delay_ms: _}` | `OTEL_BLRP_SCHEDULE_DELAY` | non-negative integer (ms) | `1000` |
| Batch export timeout | `processor_config: %{export_timeout_ms: _}` | `OTEL_BLRP_EXPORT_TIMEOUT` | integer (ms); `0` ⇒ `:infinity` | `30000` |
| Batch queue size | `processor_config: %{max_queue_size: _}` | `OTEL_BLRP_MAX_QUEUE_SIZE` | integer | `2048` |
| Batch export batch size | `processor_config: %{max_export_batch_size: _}` | `OTEL_BLRP_MAX_EXPORT_BATCH_SIZE` | integer | `512` |
| LogRecord attribute count | `log_record_limits: %{attribute_count_limit: _}` | `OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT` (fallback `OTEL_ATTRIBUTE_COUNT_LIMIT`) | integer | `128` |
| LogRecord attribute value length | `log_record_limits: %{attribute_value_length_limit: _}` | `OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT` (fallback `OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT`) | integer or `:infinity` | `:infinity` |
| Resource | `resource:` | `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_SERVICE_NAME` | `%Otel.SDK.Resource{}` | SDK identity attributes |

## Propagators

| Option | `config :otel,` | `OTEL_*` | Accepted values | Default |
|---|---|---|---|---|
| Propagators | `propagators:` | `OTEL_PROPAGATORS` | list of `:tracecontext` / `:baggage` / `:none` (or custom modules) | `[:tracecontext, :baggage]` |

The list is deduplicated. `[:none]` or an empty list installs the Noop
propagator. Spec-named propagators not bundled in this package
(`:b3`, `:b3multi`, `:jaeger`, `:xray`, `:ottrace`) raise — supply a
custom `{MyPropagator, opts}` instead.

## Disabling the SDK

| Option | `OTEL_*` | Accepted values | Default |
|---|---|---|---|
| Skip provider registration | `OTEL_SDK_DISABLED` | `true` / `false` | `false` |

When `true`, all telemetry calls become no-ops; the propagator stays active.
