# Configuration

Sources, highest priority first:

| # | Source |
|---|---|
| 1 | `OTEL_CONFIG_FILE` (YAML) — overrides everything below |
| 2 | `config :otel, ...` in `config/*.exs` |
| 3 | `OTEL_*` environment variables |
| 4 | Built-in defaults |

## Application env

```elixir
import Config

config :otel,
  trace: [
    resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"}),
    exporter: :otlp,
    span_limits: %{attribute_count_limit: 256}
  ],
  metrics: [
    resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"}),
    exporter: :otlp,
    reader_config: %{export_interval_ms: 30_000}
  ],
  logs: [
    resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"}),
    exporter: :otlp
  ],
  propagators: [:tracecontext, :baggage]
```

## OS environment

```bash
export OTEL_SERVICE_NAME=my_app
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=prod,service.version=1.2.3"
export OTEL_TRACES_SAMPLER=parentbased_always_on
export OTEL_TRACES_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp
export OTEL_METRIC_EXPORT_INTERVAL=30000
export OTEL_LOGS_EXPORTER=otlp
export OTEL_PROPAGATORS=tracecontext,baggage
```

## Declarative YAML (`OTEL_CONFIG_FILE`)

Schema: OpenTelemetry Configuration `v1.0.0`.

```yaml
# /etc/otel/config.yaml
file_format: "1.0"

resource:
  attributes_list: ${OTEL_RESOURCE_ATTRIBUTES}

propagator:
  composite:
    - tracecontext:
    - baggage:

tracer_provider:
  processors:
    - batch:
        exporter:
          otlp_http:
            endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}/v1/traces

meter_provider:
  readers:
    - periodic:
        exporter:
          otlp_http:
            endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}/v1/metrics

logger_provider:
  processors:
    - batch:
        exporter:
          otlp_http:
            endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}/v1/logs
```

```bash
export OTEL_CONFIG_FILE=/etc/otel/config.yaml
```

`${VAR}` / `${VAR:-default}` substitution works anywhere. More examples in
`test/fixtures/v1.0.0/`.

## Disable the SDK

`OTEL_SDK_DISABLED=true` makes telemetry calls no-ops. Propagator stays active.

## Selectors

Module-valued options (`exporter:`, items in `propagators:`)
accept:

- a shortcut atom (see tables below)
- a module — same as `{Module, %{}}`
- a `{module, %{...}}` tuple

## Trace pillar

Sampling is hardcoded to `parentbased_always_on`
(`Otel.SDK.Trace.Sampler`); no `sampler:` option is accepted.

| Option | `config :otel, trace:` | `OTEL_*` | Accepted values | Default |
|---|---|---|---|---|
| Exporter | `exporter:` | `OTEL_TRACES_EXPORTER` | `:otlp` / `:console` / `:none` / `Module` / `{Module, %{}}` | `:otlp` |
| Processor list | `processors:` | — | list of `{module, config}` (advanced override) | inferred |
| Batch schedule delay | `processor_config: %{scheduled_delay_ms: _}` | `OTEL_BSP_SCHEDULE_DELAY` | non-negative integer (ms) | `5000` |
| Batch export timeout | `processor_config: %{export_timeout_ms: _}` | `OTEL_BSP_EXPORT_TIMEOUT` | integer (ms); `0` ⇒ `:infinity` | `30000` |
| Batch queue size | `processor_config: %{max_queue_size: _}` | `OTEL_BSP_MAX_QUEUE_SIZE` | positive integer | `2048` |
| Batch export batch size | `processor_config: %{max_export_batch_size: _}` | `OTEL_BSP_MAX_EXPORT_BATCH_SIZE` | positive integer | `512` |
| Span attribute count | `span_limits: %{attribute_count_limit: _}` | `OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT` (or `OTEL_ATTRIBUTE_COUNT_LIMIT`) | non-negative integer | `128` |
| Span attribute value length | `span_limits: %{attribute_value_length_limit: _}` | `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT` (or `OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT`) | non-negative integer or `:infinity` | `:infinity` |
| Event count | `span_limits: %{event_count_limit: _}` | `OTEL_SPAN_EVENT_COUNT_LIMIT` | non-negative integer | `128` |
| Link count | `span_limits: %{link_count_limit: _}` | `OTEL_SPAN_LINK_COUNT_LIMIT` | non-negative integer | `128` |
| Per-event attribute count | `span_limits: %{attribute_per_event_limit: _}` | `OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT` | non-negative integer | `128` |
| Per-link attribute count | `span_limits: %{attribute_per_link_limit: _}` | `OTEL_LINK_ATTRIBUTE_COUNT_LIMIT` | non-negative integer | `128` |
| Resource | `resource:` | `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_SERVICE_NAME` | `%Otel.SDK.Resource{}` | `telemetry.sdk.*` attributes |

ID generation is hardcoded to `Otel.SDK.Trace.IdGenerator`
(random non-zero 128-bit trace IDs / 64-bit span IDs); no
`id_generator:` option is accepted.

## Metrics pillar

| Option | `config :otel, metrics:` | `OTEL_*` | Accepted values | Default |
|---|---|---|---|---|
| Exporter | `exporter:` | `OTEL_METRICS_EXPORTER` | `:otlp` / `:console` / `:none` / `Module` / `{Module, %{}}` | `:otlp` |
| Reader list | `readers:` | — | list of `{module, config}` | inferred from `exporter:` |
| Reader export interval | `reader_config: %{export_interval_ms: _}` | `OTEL_METRIC_EXPORT_INTERVAL` | non-negative integer (ms) | `60000` |
| Reader export timeout | `reader_config: %{export_timeout_ms: _}` | `OTEL_METRIC_EXPORT_TIMEOUT` | integer (ms); `0` ⇒ `:infinity` | `30000` |
| Exemplar filter | `exemplar_filter:` | `OTEL_METRICS_EXEMPLAR_FILTER` | `:always_on` / `:always_off` / `:trace_based` | `:trace_based` |
| Views | `views:` | — | list of `Otel.SDK.Metrics.View.t()` | `[]` |
| Resource | `resource:` | `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_SERVICE_NAME` | `%Otel.SDK.Resource{}` | `telemetry.sdk.*` attributes |

## Logs pillar

| Option | `config :otel, logs:` | `OTEL_*` | Accepted values | Default |
|---|---|---|---|---|
| Exporter | `exporter:` | `OTEL_LOGS_EXPORTER` | `:otlp` / `:console` / `:none` / `Module` / `{Module, %{}}` | `:otlp` |
| Processor list | `processors:` | — | list of `{module, config}` (advanced override) | inferred |
| Batch schedule delay | `processor_config: %{scheduled_delay_ms: _}` | `OTEL_BLRP_SCHEDULE_DELAY` | non-negative integer (ms) | `1000` |
| Batch export timeout | `processor_config: %{export_timeout_ms: _}` | `OTEL_BLRP_EXPORT_TIMEOUT` | integer (ms); `0` ⇒ `:infinity` | `30000` |
| Batch queue size | `processor_config: %{max_queue_size: _}` | `OTEL_BLRP_MAX_QUEUE_SIZE` | positive integer | `2048` |
| Batch export batch size | `processor_config: %{max_export_batch_size: _}` | `OTEL_BLRP_MAX_EXPORT_BATCH_SIZE` | positive integer | `512` |
| LogRecord attribute count | `log_record_limits: %{attribute_count_limit: _}` | `OTEL_LOGRECORD_ATTRIBUTE_COUNT_LIMIT` (or `OTEL_ATTRIBUTE_COUNT_LIMIT`) | non-negative integer | `128` |
| LogRecord attribute value length | `log_record_limits: %{attribute_value_length_limit: _}` | `OTEL_LOGRECORD_ATTRIBUTE_VALUE_LENGTH_LIMIT` (or `OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT`) | non-negative integer or `:infinity` | `:infinity` |
| Resource | `resource:` | `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_SERVICE_NAME` | `%Otel.SDK.Resource{}` | `telemetry.sdk.*` attributes |

## Propagators

| Option | `config :otel,` | `OTEL_*` | Accepted values | Default |
|---|---|---|---|---|
| Propagators | `propagators:` | `OTEL_PROPAGATORS` | list of `:tracecontext` / `:baggage` / `:none` (or custom modules) | `[:tracecontext, :baggage]` |

Deduplicated. `[:none]` or `[]` → Noop. `:b3` / `:b3multi` / `:jaeger` /
`:xray` / `:ottrace` raise; supply a custom module instead.

## OTLP HTTP — SSL / TLS

The OTLP HTTP exporter uses Erlang's `:httpc`. For `https://` endpoints,
certificate verification is enabled by default using system CA
certificates (`:public_key.cacerts_get/0`).

To override the defaults — custom CA bundle, mutual TLS, etc. — pass
the exporter explicitly with an `ssl_options:` keyword list:

```elixir
config :otel,
  trace: [
    exporter:
      {Otel.OTLP.Trace.SpanExporter.HTTP,
       %{
         endpoint: "https://collector.example.com:4318/v1/traces",
         ssl_options: [
           verify: :verify_peer,
           cacertfile: "/etc/ssl/certs/ca.crt"
         ]
       }}
  ]
```

`ssl_options:` accepts any
[Erlang `:ssl` client_option](https://www.erlang.org/doc/apps/ssl/ssl.html#client_option).
Common patterns:

| Pattern | Options |
|---|---|
| Custom CA bundle | `verify: :verify_peer, cacertfile: "ca.crt"` |
| Mutual TLS | add `certfile: "client.crt", keyfile: "client.key"` |
| Disable verification (dev only) | `verify: :verify_none` |

The same `{Module, opts}` shape works for `metrics:`
(`Otel.OTLP.Metrics.MetricExporter.HTTP`) and `logs:`
(`Otel.OTLP.Logs.LogRecordExporter.HTTP`).
