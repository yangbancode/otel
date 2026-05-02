# Configuration

Sources, highest priority first:

| # | Source |
|---|---|
| 1 | `config :otel, ...` in `config/*.exs` |
| 2 | `OTEL_*` environment variables |
| 3 | Built-in defaults |

## Application env

```elixir
import Config

config :otel,
  trace: [
    resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"})
  ],
  metrics: [
    resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"}),
    reader_config: %{export_interval_ms: 30_000}
  ],
  logs: [
    resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"})
  ]
```

## OS environment

```bash
export OTEL_SERVICE_NAME=my_app
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=prod,service.version=1.2.3"
```

## Disable the SDK

`OTEL_SDK_DISABLED=true` makes telemetry calls no-ops. Propagator stays active.

## Trace pillar

Exporter is hardcoded to **OTLP/HTTP** (`Otel.OTLP.Trace.SpanExporter.HTTP`).
No `exporter:` option, no Console exporter, no `:none` shortcut. To stop
emitting telemetry, set `config :otel, disabled: true` (or
`OTEL_SDK_DISABLED=true`).

Sampling is hardcoded to `parentbased_always_on`
(`Otel.SDK.Trace.Sampler`); no `sampler:` option is accepted.

| Option | `config :otel, trace:` | `OTEL_*` | Accepted values | Default |
|---|---|---|---|---|
| Processor list | `processors:` | — | list of `{module, config}` (advanced override; mostly for tests) | inferred |
| Resource | `resource:` | `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_SERVICE_NAME` | `%Otel.SDK.Resource{}` | `telemetry.sdk.*` attributes |

ID generation is hardcoded to `Otel.SDK.Trace.IdGenerator`
(random non-zero 128-bit trace IDs / 64-bit span IDs); no
`id_generator:` option is accepted.

Span batch processor knobs (`max_queue_size: 2048`,
`scheduled_delay_ms: 5000`, `export_timeout_ms: 30_000`,
`max_export_batch_size: 512`) are hardcoded to spec defaults
(`trace/sdk.md` L1109-L1118); `OTEL_BSP_*` env vars are not
read.

Span limits are hardcoded to spec defaults (all `128`,
`attribute_value_length_limit: :infinity`, see
`trace/sdk.md` L868-871 and `common/README.md` L305-306);
`OTEL_SPAN_*_LIMIT` / `OTEL_EVENT_*` / `OTEL_LINK_*` /
`OTEL_ATTRIBUTE_*` env vars are not read. The
`:span_limits` Application-env keyword is retained as an
advanced override for tests that need to exercise the
limit-enforcement code paths with small caps.

## Metrics pillar

Exporter is hardcoded to **OTLP/HTTP** (`Otel.OTLP.Metrics.MetricExporter.HTTP`).

| Option | `config :otel, metrics:` | `OTEL_*` | Accepted values | Default |
|---|---|---|---|---|
| Reader list | `readers:` | — | list of `{module, config}` (advanced override; mostly for tests) | inferred |
| Resource | `resource:` | `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_SERVICE_NAME` | `%Otel.SDK.Resource{}` | `telemetry.sdk.*` attributes |

PeriodicExporting reader interval / timeout are hardcoded to
spec defaults (`metrics/sdk.md` L1450-L1453:
`exportIntervalMillis` `60000`, `exportTimeoutMillis`
`30000`). `OTEL_METRIC_EXPORT_INTERVAL` /
`OTEL_METRIC_EXPORT_TIMEOUT` env vars and the
`:reader_config` Application-env keyword are no longer read.

Exemplar filter is hardcoded to **`:trace_based`** — the
spec default per `metrics/sdk.md` L1123 (*"The default value
SHOULD be `TraceBased`"*). `OTEL_METRICS_EXEMPLAR_FILTER`
env var is no longer read. The `:exemplar_filter`
Application-env keyword is retained as an advanced override
for tests that exercise the `:always_on` / `:always_off`
filter paths.

## Logs pillar

Exporter is hardcoded to **OTLP/HTTP** (`Otel.OTLP.Logs.LogRecordExporter.HTTP`).

| Option | `config :otel, logs:` | `OTEL_*` | Accepted values | Default |
|---|---|---|---|---|
| Processor list | `processors:` | — | list of `{module, config}` (advanced override; mostly for tests) | inferred |
| Resource | `resource:` | `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_SERVICE_NAME` | `%Otel.SDK.Resource{}` | `telemetry.sdk.*` attributes |

LogRecord batch processor knobs (same shape as the trace
pillar, with `scheduled_delay_ms` defaulting to `1000`) are
hardcoded; `OTEL_BLRP_*` env vars are not read.

LogRecord limits are hardcoded to spec defaults
(`attribute_count_limit: 128`,
`attribute_value_length_limit: :infinity`, see
`logs/sdk.md` L321 and `common/README.md` L305-306);
`OTEL_LOGRECORD_*_LIMIT` / `OTEL_ATTRIBUTE_*` env vars
are not read. The `:log_record_limits` Application-env
keyword is retained as an advanced override for tests.

## Propagators

Propagators are hardcoded to
**`Composite[TraceContext, Baggage]`** — the OTel spec
default per `sdk-environment-variables.md` L118 and
`context/api-propagators.md` L329-331. Not configurable.

The `:propagators` Application-env keyword and
`OTEL_PROPAGATORS` env var are no longer read. Other
spec-listed propagators (`:b3`, `:b3multi`, `:jaeger`,
`:xray`, `:ottrace`) are not supported in this SDK; users
needing them should use `opentelemetry-erlang`.

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
