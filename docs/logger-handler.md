# Logger Handler

`Otel.LoggerHandler` bridges Erlang's `:logger` to the OpenTelemetry Logs
API. Every call to `Logger.info/2`, `:logger.error/1`, etc. is converted
into an `Otel.API.Logs.LogRecord` and emitted through the configured
`LoggerProvider` — when the SDK is installed, records flow through
processors to exporters; without an SDK, they silently drop through the
Noop logger.

## Attaching the handler

```elixir
:logger.add_handler(:otel, Otel.LoggerHandler, %{
  config: %{
    scope_name: "my_app",
    scope_version: "1.0.0"
  }
})
```

Attach this once during application boot — for example, in your
`Application.start/2` callback — alongside any other `:logger`
handlers you use (`:default`, `LoggerJSON`, etc.).

## Config keys

All handler-specific options live under the handler config's `:config`
key (`:logger.handler_config()`). Every key is optional.

| Key | Default | Description |
|---|---|---|
| `scope_name` | `""` | `Otel.API.InstrumentationScope.name` — **SHOULD** be the calling application or library name (typically your app's atom rendered as a string). Empty values are accepted but lose origin identification at the backend. |
| `scope_version` | `""` | `Otel.API.InstrumentationScope.version` — typically `Application.spec(:my_app, :vsn) \|> to_string()`. |
| `scope_schema_url` | `""` | `Otel.API.InstrumentationScope.schema_url` (OTel spec v1.13.0+). |
| `scope_attributes` | `%{}` | `Otel.API.InstrumentationScope.attributes`. Follows OTel attribute rules: primitives or homogeneous arrays only. |

The four `scope_*` keys form an `Otel.API.InstrumentationScope` rebuilt
on every event. The `LoggerProvider` is resolved per-event rather than
cached at attach-time so the handler picks up an SDK that boots after
`:logger` itself.

## What the handler emits

| LogRecord field | Source |
|---|---|
| `severity_number` / `severity_text` | `:logger` level → OTel SeverityNumber per `logs/data-model.md` §Mapping of `SeverityNumber` (RFC 5424 syslog levels). `:emergency` → 21, `:alert` → 19, `:critical` → 18, `:error` → 17, `:warning` → 13, `:notice` → 10, `:info` → 9, `:debug` → 5. |
| `body` | `:logger` `msg` field — `{:string, _}`, `{:report, _}`, or `{format, args}`. Reports preserve structure; reports with a `:report_cb` callback are flattened via that callback. |
| `timestamp` | `meta.time` (microseconds → nanoseconds). |
| `attributes` | Semconv-mapped from `meta.mfa` (→ `code.function.name`), `meta.file` (→ `code.file.path`), `meta.line` (→ `code.line.number`), `meta.domain` (→ `log.domain`). All other non-reserved `meta` keys flow through verbatim as custom attributes. |
| `exception` | When `meta.crash_reason` is `{exception, stacktrace}`, the exception struct is attached and `exception.stacktrace` (formatted) is emitted as an attribute. |

Reserved meta keys (never emitted as attributes): `:time`, `:gl`,
`:report_cb`, `:crash_reason`.

## Pairing with the SDK

The handler does no batching of its own — that's the SDK's
`LogRecordProcessor` job. For production deployments configure the SDK's
Logs pillar with the Batch processor (the default):

```elixir
config :otel,
  logs: [
    exporter: :otlp,
    processor: :batch
  ]
```

See [Configuration](configuration.md) for the full list of Logs-pillar
knobs (`OTEL_BLRP_*` env vars, `processor_config:` overrides, log-record
limits, etc.).
