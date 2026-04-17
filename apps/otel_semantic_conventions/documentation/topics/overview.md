# What are Semantic Conventions?

OpenTelemetry [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/) define a vendor-neutral, standardized vocabulary for the attribute keys, metric names, and resource descriptors that telemetry signals carry.

When two services in the same system both record an HTTP request, they should both emit the request method under the same key — `http.request.method` — not `http_method`, `httpMethod`, or `request.method`. Otherwise, dashboards, alerts, and trace search across services break.

## Why this package exists

This package exposes those standardized keys as Elixir constants:

```elixir
iex> Otel.SemConv.Attributes.HTTP.http_request_method()
"http.request.method"
```

The function returns the exact `String.t()` your span/metric/log emitter should use. There are three reasons to call this instead of typing `"http.request.method"` as a string literal:

1. **Typo safety** — `http_request_methdo` is a compile-time error; `"http.request.methdo"` is a silent runtime bug.
2. **Discoverability** — `Otel.SemConv.Attributes.HTTP.` autocompletes in IDE/iex, surfacing related keys.
3. **Single source of truth** — when the spec evolves, regenerating this package propagates changes; string literals scattered across your code do not.

## Stable items only

The OTel spec classifies each attribute and metric as **stable**, **development**, **experimental**, or **deprecated**. This package generates **only stable items** — items with backward-compatibility guarantees from the spec.

> ### Why exclude experimental? {: .info}
>
> Experimental attributes can be removed or renamed without notice. Including them would create churn in this package's API surface every time the upstream spec iterates. If you need experimental keys, declare them as string literals in your code with a comment explaining the version they came from.

## Module organization

| Namespace | Contents |
|---|---|
| `Otel.SemConv.Attributes.*` | attribute key constants (`HTTP`, `DB`, `URL`, `K8S`, `Network`, `Server`, ...) |
| `Otel.SemConv.Metrics.*` | metric name constants (`HTTP`, `DB`) |

Module names preserve common acronyms exactly — `HTTP` instead of `Http`, `DB` instead of `Db`.

## Excluded domains

The OTel spec also defines attributes for runtime/framework internals that have no meaningful counterpart on the BEAM. The following groups are intentionally excluded from generation:

- `aspnetcore`, `dotnet`, `kestrel`, `signalr` — .NET / ASP.NET internals
- `jvm` — JVM runtime internals

A future Elixir runtime semantic-convention proposal could change this. For now, an Elixir developer has no legitimate way to populate `Otel.SemConv.Attributes.JVM.jvm_thread_count()`.

## Spec version

Each release pins to one upstream OTel Semantic Conventions spec version. The mapping is in [`README.md`](../../README.md) and per-release in [`CHANGELOG.md`](../../CHANGELOG.md).
