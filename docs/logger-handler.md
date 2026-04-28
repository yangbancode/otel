# Logger Handler

Bridges Erlang's `:logger` to OpenTelemetry Logs. Every `Logger.info/2`
call becomes a `LogRecord` emitted via the configured `LoggerProvider`.
With the SDK installed, records flow to exporters; without one, they
drop silently.

## Attach the handler

```elixir
:logger.add_handler(:otel, Otel.LoggerHandler, %{
  config: %{
    scope_name: "my_app",
    scope_version: "1.0.0"
  }
})
```

Attach once at application start, alongside any other handlers you use.

## Config keys

All under the handler's `:config` key. Every key is optional.

| Key | Default | Description |
|---|---|---|
| `scope_name` | `""` | InstrumentationScope name — set to your app/library name |
| `scope_version` | `""` | typically `Application.spec(:my_app, :vsn) \|> to_string()` |
| `scope_schema_url` | `""` | InstrumentationScope schema URL |
| `scope_attributes` | `%{}` | InstrumentationScope attributes (primitives + homogeneous arrays) |

## What gets emitted

| LogRecord field | Source |
|---|---|
| `severity_number` / `severity_text` | `:logger` level (`:emergency` → 21, `:alert` → 19, `:critical` → 18, `:error` → 17, `:warning` → 13, `:notice` → 10, `:info` → 9, `:debug` → 5) |
| `body` | `:logger` `msg` field — `{:string, _}` / `{:report, _}` / `{format, args}`. Reports preserve structure; `:report_cb` callbacks flatten them |
| `timestamp` | `meta.time` (µs → ns) |
| `attributes` | `meta.mfa` → `code.function.name`; `meta.file` → `code.file.path`; `meta.line` → `code.line.number`; `meta.domain` → `log.domain`. Other non-reserved meta keys pass through verbatim |
| `exception` | `meta.crash_reason = {exception, stacktrace}` → exception struct attached + `exception.stacktrace` attribute |

Reserved meta keys (never emitted as attributes): `:time`, `:gl`,
`:report_cb`, `:crash_reason`.

## Pairing with the SDK

The handler does no batching — that's `LogRecordProcessor`'s job. The
default config (Batch + OTLP) is fine for production:

```elixir
config :otel, logs: [exporter: :otlp, processor: :batch]
```

See [Configuration](configuration.md) for Logs-pillar knobs (`OTEL_BLRP_*`,
`processor_config:`, log-record limits).
