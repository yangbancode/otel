# Logger Handler

Bridges Erlang's `:logger` to OpenTelemetry Logs.

## Attach the handler

```elixir
:logger.add_handler(:otel, Otel.LoggerHandler, %{
  config: %{
    scope_name: "my_app",
    scope_version: "1.0.0"
  }
})
```

## Config keys

All under `:config`. Optional.

| Key | Default | Description |
|---|---|---|
| `scope_name` | `""` | InstrumentationScope name — your app/library name |
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

Pair with the SDK's processor pipeline (default `:batch`):

```elixir
config :otel, logs: [exporter: :otlp, processor: :batch]
```

See [Configuration](configuration.md) for Logs-pillar knobs.
