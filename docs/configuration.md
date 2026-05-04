# Configuration

The SDK reads only Application env. Sources, highest priority first:

| # | Source |
|---|---|
| 1 | `start_link(config: ...)` passed directly to a provider |
| 2 | `config :otel, ...` in `config/*.exs` |
| 3 | Built-in defaults |

## User-facing keys

Two top-level keys cover everything most users need.

```elixir
import Config

config :otel,
  otp_app: :my_app,
  exporter: %{endpoint: "http://localhost:4318"}
```

| Key | Type | Default |
|---|---|---|
| `:otp_app` | `atom()` (your application's `:app` from `mix.exs`) | none — `service.name` falls back to `"unknown_service"` |
| `:exporter` | `%{endpoint, headers, ssl_options, ...}` | `%{}` (uses exporter defaults) |

`:otp_app` is the only resource knob. The SDK derives:

- `service.name` from `:otp_app` (or `"unknown_service"` when absent)
- `service.version` from `Application.spec(:otp_app, :vsn)` (or `""`)
- `telemetry.sdk.{name,language,version}` and `deployment.environment`
  from compile-time literals

See `Otel.Resource` for the full attribute set. Custom resource
attributes and Schema URL are not supported — power users wanting
either should use [`opentelemetry-erlang`](https://github.com/open-telemetry/opentelemetry-erlang).

The `:exporter` map is forwarded verbatim to all three OTLP/HTTP
exporters (trace, metrics, logs). Common keys:

| Exporter key | Default | Notes |
|---|---|---|
| `:endpoint` | `http://localhost:4318` | `/v1/traces`, `/v1/metrics`, `/v1/logs` are appended per signal |
| `:headers` | `%{}` | `%{header_name => value}` — use for SaaS auth tokens |
| `:ssl_options` | system CAs for HTTPS | Erlang `:ssl` client options |

`:compression` and `:timeout` are also accepted by the exporter
modules but rarely need adjustment. Retry behavior is hardcoded to
the Java OTLP defaults (5 attempts, 1s → 5s exponential backoff,
±20% jitter) and is not user-tunable.

## Bridging OS environment variables (Phoenix pattern)

The SDK does not read `OTEL_*` env vars directly. Bridge the
exporter endpoint in your `runtime.exs` — same pattern as
Phoenix's `PHX_SERVER`:

```elixir
# config/runtime.exs
import Config

config :otel,
  otp_app: :my_app,
  exporter: %{
    endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") || "http://localhost:4318"
  }
```

`OTEL_SERVICE_NAME` and `OTEL_RESOURCE_ATTRIBUTES` are not
bridged — `:otp_app` is the single resource knob.

## Disabling the SDK

There is no runtime kill switch. To disable telemetry — typically in
test environments or CI without a collector — exclude `:otel` from
your application's `extra_applications`:

```elixir
# mix.exs
def application do
  [extra_applications: extra_apps()]
end

defp extra_apps do
  base = [:logger]
  if Mix.env() == :test, do: base, else: base ++ [:otel]
end
```

When `:otel` isn't loaded, no providers start and telemetry calls
will raise (`UndefinedFunctionError` on the unloaded modules) — wrap
your call sites or scope `:otel` per environment as above.

For tests that want to assert telemetry behaviour without hitting a
real collector, use the advanced `:processors` / `:readers` overrides
to inject a mock exporter (see "Advanced overrides" below).

## Trace pillar

Exporter is hardcoded to **OTLP/HTTP** (`Otel.Trace.SpanExporter`).
No `exporter:` option, no Console exporter, no `:none` shortcut.

Sampling is hardcoded to `parentbased_always_on`
(`Otel.Trace.Sampler`); no `sampler:` option is accepted.

ID generation is hardcoded to `Otel.Trace.IdGenerator`
(random non-zero 128-bit trace IDs / 64-bit span IDs); no
`id_generator:` option is accepted.

Span batch processor knobs (`max_queue_size: 2048`,
`scheduled_delay_ms: 5000`, `export_timeout_ms: 30_000`,
`max_export_batch_size: 512`) are hardcoded to spec defaults
(`trace/sdk.md` L1109-L1118).

Span limits are hardcoded to spec defaults (all `128`,
`attribute_value_length_limit: :infinity`, see
`trace/sdk.md` L868-871 and `common/README.md` L305-306).

## Metrics pillar

Exporter is hardcoded to **OTLP/HTTP** (`Otel.OTLP.Metrics.MetricExporter`).

PeriodicExporting reader interval / timeout are hardcoded to
spec defaults (`metrics/sdk.md` L1450-L1453:
`exportIntervalMillis` `60000`, `exportTimeoutMillis`
`30000`).

Exemplar filter is hardcoded to **`:trace_based`** — the
spec default per `metrics/sdk.md` L1123 (*"The default value
SHOULD be `TraceBased`"*).

## Logs pillar

Exporter is hardcoded to **OTLP/HTTP** (`Otel.OTLP.Logs.LogRecordExporter`).

LogRecord batch processor knobs (same shape as the trace
pillar, with `scheduled_delay_ms` defaulting to `1000`) are
hardcoded.

LogRecord limits are hardcoded to spec defaults
(`attribute_count_limit: 128`,
`attribute_value_length_limit: :infinity`, see
`logs/sdk.md` L321 and `common/README.md` L305-306).

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
options through the top-level `:exporter` map:

```elixir
config :otel,
  otp_app: :my_app,
  exporter: %{
    endpoint: "https://collector.example.com:4318",
    ssl_options: [
      verify: :verify_peer,
      cacertfile: "/etc/ssl/certs/ca.crt"
    ]
  }
```

`ssl_options:` accepts any
[Erlang `:ssl` client_option](https://www.erlang.org/doc/apps/ssl/ssl.html#client_option).
Common patterns:

| Pattern | Options |
|---|---|
| Custom CA bundle | `verify: :verify_peer, cacertfile: "ca.crt"` |
| Mutual TLS | add `certfile: "client.crt", keyfile: "client.key"` |
| Disable verification (dev only) | `verify: :verify_none` |

## What's *not* user-configurable

By design (minikube-style), there is no knob for:

- SpanProcessor / LogRecordProcessor (always Batch)
- MetricReader (always PeriodicExporting, 60s interval / 30s timeout)
- SpanLimits / LogRecordLimits (spec defaults)
- Exemplar filter (always `:trace_based`)
- Retry behavior (Java OTLP defaults)
- Custom resource attributes (only `:otp_app`-derived `service.*` and SDK identity attributes are emitted)
- Resource Schema URL

Power users wanting custom processors / readers / limits / filters
should use [`opentelemetry-erlang`](https://github.com/open-telemetry/opentelemetry-erlang).
