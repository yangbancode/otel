# Otel Semantic Conventions

[![Hex.pm](https://img.shields.io/hexpm/v/otel_semantic_conventions.svg)](https://hex.pm/packages/otel_semantic_conventions)
[![Hexdocs.pm](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/otel_semantic_conventions)
[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](https://unlicense.org/)

Pure Elixir implementation of [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/).

Part of the [Otel](https://github.com/yangbancode/otel) umbrella project, a pure Elixir implementation of OpenTelemetry.

## Requirements

- Elixir ~> 1.19
- Erlang/OTP ~> 28

## Compatibility

| Package | OTel Semantic Conventions |
|---|---|
| `0.1.x` | [v1.40.0](https://github.com/open-telemetry/semantic-conventions/releases/tag/v1.40.0) |

Only **stable** items are generated. Experimental, development, and deprecated items are out of scope — see the [Overview](documentation/topics/overview.md) for the rationale.

## Installation

Add the dependency to your `mix.exs`:

```elixir
def deps do
  [
    {:otel_semantic_conventions, "~> 0.1"}
  ]
end
```

## About the Documentation

This package's documentation follows the [Diátaxis](https://diataxis.fr/) framework:

- **Topics** — conceptual explanations of *what* and *why*
- **How-to** — task-focused recipes for getting things done
- **Reference** — auto-generated module API docs (sidebar)

## Topics

- [Overview](documentation/topics/overview.md) — what semantic conventions are, why this package generates only stable items, and how the modules are organized

## How-to

- [Using Semantic Convention Constants with Spans](documentation/how-to/use-with-spans.md) — recipes for HTTP server, database, and error attribute patterns

## Reference

The full API reference is in the sidebar. Constants are organized into two namespaces:

| Namespace | Contents |
|---|---|
| `Otel.SemConv.Attributes.*` | attribute key constants (e.g., `HTTP`, `DB`, `URL`, `K8S`) |
| `Otel.SemConv.Metrics.*` | metric name constants (e.g., `HTTP`, `DB`) |

Module names preserve common acronyms exactly (`HTTP`, not `Http`).

## Quick Example

```elixir
iex> Otel.SemConv.Attributes.HTTP.http_request_method()
"http.request.method"

iex> Otel.SemConv.Attributes.HTTP.http_request_method_values()[:post]
"POST"
```

Use these in place of string literals when emitting attributes — see the [how-to guide](documentation/how-to/use-with-spans.md) for full patterns.

## License

Released into the public domain under the [Unlicense](LICENSE).
