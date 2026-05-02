# Configuration

The SDK reads only Application env. Sources, highest priority first:

| # | Source |
|---|---|
| 1 | `start_link(config: ...)` passed directly to a provider |
| 2 | `config :otel, ...` in `config/*.exs` |
| 3 | Built-in defaults |

## Application env

```elixir
import Config

config :otel,
  trace: [
    resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"})
  ],
  metrics: [
    resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"})
  ],
  logs: [
    resource: Otel.SDK.Resource.create(%{"service.name" => "my_app"})
  ]
```

## Bridging OS environment variables (Phoenix pattern)

The SDK does not read `OTEL_*` env vars directly. Bridge them in
your `runtime.exs` — same pattern as Phoenix's `PHX_SERVER`:

```elixir
# config/runtime.exs
import Config

service_name = System.get_env("OTEL_SERVICE_NAME") || "my_app"

extra_attrs =
  "OTEL_RESOURCE_ATTRIBUTES"
  |> System.get_env("")
  |> String.split(",", trim: true)
  |> Map.new(fn pair ->
    [k, v] = String.split(pair, "=", parts: 2)
    {k, v}
  end)

resource =
  extra_attrs
  |> Map.put("service.name", service_name)
  |> Otel.SDK.Resource.create()

endpoint = System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") || "http://localhost:4318"

config :otel,
  disabled: System.get_env("OTEL_SDK_DISABLED") == "true",
  trace: [
    resource: resource,
    exporter: {Otel.OTLP.Trace.SpanExporter, %{endpoint: endpoint}}
  ],
  metrics: [
    resource: resource,
    readers: [
      {Otel.SDK.Metrics.MetricReader.PeriodicExporting,
       %{exporter: {Otel.OTLP.Metrics.MetricExporter, %{endpoint: endpoint}}}}
    ]
  ],
  logs: [
    resource: resource,
    exporter: {Otel.OTLP.Logs.LogRecordExporter, %{endpoint: endpoint}}
  ]
```

## Disable the SDK

`config :otel, disabled: true` makes telemetry calls no-ops. Propagator
stays active.

## Trace pillar

Exporter is hardcoded to **OTLP/HTTP** (`Otel.OTLP.Trace.SpanExporter`).
No `exporter:` option, no Console exporter, no `:none` shortcut. To stop
emitting telemetry, set `config :otel, disabled: true`.

Sampling is hardcoded to `parentbased_always_on`
(`Otel.SDK.Trace.Sampler`); no `sampler:` option is accepted.

| Option | `config :otel, trace:` | Accepted values | Default |
|---|---|---|---|
| Processor list | `processors:` | list of `{module, config}` (advanced override; mostly for tests) | inferred |
| Resource | `resource:` | `%Otel.SDK.Resource{}` | `telemetry.sdk.*` attributes + `service.name=unknown_service` |

ID generation is hardcoded to `Otel.SDK.Trace.IdGenerator`
(random non-zero 128-bit trace IDs / 64-bit span IDs); no
`id_generator:` option is accepted.

Span batch processor knobs (`max_queue_size: 2048`,
`scheduled_delay_ms: 5000`, `export_timeout_ms: 30_000`,
`max_export_batch_size: 512`) are hardcoded to spec defaults
(`trace/sdk.md` L1109-L1118).

Span limits are hardcoded to spec defaults (all `128`,
`attribute_value_length_limit: :infinity`, see
`trace/sdk.md` L868-871 and `common/README.md` L305-306). The
`:span_limits` Application-env keyword is retained as an
advanced override for tests that need to exercise the
limit-enforcement code paths with small caps.

## Metrics pillar

Exporter is hardcoded to **OTLP/HTTP** (`Otel.OTLP.Metrics.MetricExporter`).

| Option | `config :otel, metrics:` | Accepted values | Default |
|---|---|---|---|
| Reader list | `readers:` | list of `{module, config}` (advanced override; mostly for tests) | inferred |
| Resource | `resource:` | `%Otel.SDK.Resource{}` | `telemetry.sdk.*` attributes + `service.name=unknown_service` |

PeriodicExporting reader interval / timeout are hardcoded to
spec defaults (`metrics/sdk.md` L1450-L1453:
`exportIntervalMillis` `60000`, `exportTimeoutMillis`
`30000`).

Exemplar filter is hardcoded to **`:trace_based`** — the
spec default per `metrics/sdk.md` L1123 (*"The default value
SHOULD be `TraceBased`"*). The `:exemplar_filter`
Application-env keyword is retained as an advanced override
for tests that exercise the `:always_on` / `:always_off`
filter paths.

## Logs pillar

Exporter is hardcoded to **OTLP/HTTP** (`Otel.OTLP.Logs.LogRecordExporter`).

| Option | `config :otel, logs:` | Accepted values | Default |
|---|---|---|---|
| Processor list | `processors:` | list of `{module, config}` (advanced override; mostly for tests) | inferred |
| Resource | `resource:` | `%Otel.SDK.Resource{}` | `telemetry.sdk.*` attributes + `service.name=unknown_service` |

LogRecord batch processor knobs (same shape as the trace
pillar, with `scheduled_delay_ms` defaulting to `1000`) are
hardcoded.

LogRecord limits are hardcoded to spec defaults
(`attribute_count_limit: 128`,
`attribute_value_length_limit: :infinity`, see
`logs/sdk.md` L321 and `common/README.md` L305-306). The
`:log_record_limits` Application-env keyword is retained as
an advanced override for tests.

## Propagators

Propagators are hardcoded to
**`Composite[TraceContext, Baggage]`** — the OTel spec
default per `sdk-environment-variables.md` L118 and
`context/api-propagators.md` L329-331. Not configurable.

Other spec-listed propagators (`:b3`, `:b3multi`, `:jaeger`,
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
      {Otel.OTLP.Trace.SpanExporter,
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
(`Otel.OTLP.Metrics.MetricExporter`) and `logs:`
(`Otel.OTLP.Logs.LogRecordExporter`).
