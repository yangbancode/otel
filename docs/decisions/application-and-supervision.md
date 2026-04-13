# Application & Supervision Tree

## Question

How should the SDK OTP Application be structured? How to read user config, apply defaults, and start the supervision tree?

## Decision

### Application start

`Otel.SDK.Application.start/2` reads config from `Application.get_all_env(:otel_sdk)`, merges with defaults, and starts the supervision tree.

### Default configuration

| Config | Default | Description |
|---|---|---|
| `sampler` | `{ParentBased, %{root: {AlwaysOn, %{}}}}` | Sampling strategy |
| `processors` | `[]` | Span processors with exporters |
| `id_generator` | `IdGenerator.Default` | Trace/span ID generation |
| `resource` | `%{}` | Resource attributes |
| `span_limits` | `%SpanLimits{}` | Attribute/event/link limits |

When no processors are configured, no spans are exported (silent no-op).

### Supervision tree

```
Otel.SDK.Supervisor (one_for_one)
├── Otel.SDK.Trace.SpanStorage
└── Otel.SDK.Trace.TracerProvider (config from Application env)
```

SpanStorage is always started. TracerProvider reads config and registers as the global provider, replacing the API-level Noop.

### User configuration

```elixir
# config/config.exs
config :otel_sdk,
  sampler: {Otel.SDK.Trace.Sampler.AlwaysOn, %{}},
  processors: [
    {Otel.SDK.Trace.SimpleProcessor, %{
      exporter: {Otel.SDK.Trace.Exporter.Console, %{}}
    }}
  ]
```

### Module: `Otel.SDK.Application`

Location: `apps/otel_sdk/lib/otel/sdk/application.ex`

## Compliance
