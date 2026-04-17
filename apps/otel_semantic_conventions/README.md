# Otel Semantic Conventions

[![Hex.pm](https://img.shields.io/hexpm/v/otel_semantic_conventions.svg)](https://hex.pm/packages/otel_semantic_conventions)
[![Hexdocs.pm](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/otel_semantic_conventions)
[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](https://unlicense.org/)

Pure Elixir implementation of [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/).

Part of the [Otel](https://github.com/yangbancode/otel) umbrella project, a pure Elixir implementation of OpenTelemetry.

## Requirements

- Elixir 1.18+
- Erlang/OTP 26+

## Compatibility

| Package | Semantic Conventions |
|---|---|
| `0.1.x` | [v1.40.0](https://github.com/open-telemetry/semantic-conventions/releases/tag/v1.40.0) |

> #### Scope {: .info}
>
> Generates **stable** attributes and metrics only.

## Installation

Add the dependency to your `mix.exs`:

```elixir
def deps do
  [
    {:otel_semantic_conventions, "~> 0.1"}
  ]
end
```

## Quick Example

```elixir
iex> Otel.SemConv.Attributes.HTTP.http_request_method()
"http.request.method"

iex> Otel.SemConv.Attributes.HTTP.http_request_method_values()[:post]
"POST"
```

## Module Organization

Constants are organized into two namespaces, visible in the sidebar:

| Namespace | Contents |
|---|---|
| `Otel.SemConv.Attributes.*` | attribute key constants (e.g., `HTTP`, `DB`, `URL`, `K8S`) |
| `Otel.SemConv.Metrics.*` | metric name constants (e.g., `HTTP`, `DB`) |

Module names preserve common acronyms exactly (`HTTP`, not `Http`).

## License

Released into the public domain under the [Unlicense](LICENSE).
