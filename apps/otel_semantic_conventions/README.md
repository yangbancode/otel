# Otel Semantic Conventions

> [!WARNING]
> **Status: Alpha** — API may change in `0.x` minor releases. Not recommended for production use yet.

OpenTelemetry [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/) for Elixir — auto-generated attribute and metric key constants from the official OTel spec.

Part of the [`otel`](https://github.com/yangbancode/otel) umbrella project, a pure Elixir implementation of the OpenTelemetry SDK.

## Spec Version Mapping

| Package Version | OTel Semantic Conventions Spec |
|---|---|
| `0.1.x` | [v1.40.0](https://github.com/open-telemetry/semantic-conventions/releases/tag/v1.40.0) |

Only **stable** items are generated. Experimental/incubating attributes and metrics are out of scope (see [the generation decision](https://github.com/yangbancode/otel/blob/main/docs/decisions/semantic-conventions-code-generation.md)).

## Installation

Add the dependency to your `mix.exs`:

```elixir
def deps do
  [
    {:otel_semantic_conventions, "~> 0.1"}
  ]
end
```

## Usage

Each attribute is exposed as a zero-arity function returning the attribute key as a `String.t()`:

```elixir
iex> Otel.SemConv.Attributes.HTTP.http_request_method()
"http.request.method"
```

For enum attributes, an additional `_values()` helper returns a member-to-value map. Use the atom keys as Elixir-side handles to look up the canonical wire value:

```elixir
iex> Otel.SemConv.Attributes.HTTP.http_request_method_values()[:connect]
"CONNECT"
```

Use the constants directly when emitting attributes on spans, metrics, or log records:

```elixir
Otel.API.Trace.Span.set_attribute(
  span,
  Otel.SemConv.Attributes.HTTP.http_request_method(),
  "POST"
)
```

## Module Organization

| Namespace | Contents |
|---|---|
| `Otel.SemConv.Attributes.*` | attribute groups (e.g., `HTTP`, `DB`, `URL`, `K8S`, `Network`) |
| `Otel.SemConv.Metrics.*` | metric groups (e.g., `HTTP`, `DB`) |

Module names preserve common acronyms exactly (`HTTP`, not `Http`).

## Excluded Domains

The following runtime/framework-specific domains are intentionally excluded since they describe internals not observable from the BEAM:

- `aspnetcore`, `dotnet`, `kestrel`, `signalr` — .NET / ASP.NET internals
- `jvm` — JVM runtime internals

## License

Released into the public domain under the [Unlicense](LICENSE).
