# Minimum Elixir Version

## Question

What is the minimum Elixir version this project should support? Should it match the development version or target broader compatibility for hex.pm users?

## Decision

### Minimum Versions

- **Elixir**: `~> 1.19`
- **Erlang/OTP**: `~> 28.0`

These match the current development versions pinned in `.mise.toml`. All `mix.exs` files in the umbrella already declare `elixir: "~> 1.19"`.

### Rationale

This is a new project with no existing users. Starting with the latest versions avoids maintaining compatibility shims and allows the SDK to leverage modern features from the beginning.

#### OTP 28 features used by this SDK

- **Priority messages (EEP 76)** — flush/shutdown signals skip the normal message queue, critical for reliable exporter shutdown
- **`persistent_term:put_new/2`** — atomic one-time initialization for SDK configuration
- **`zstd` module** — native Zstandard compression for OTLP export payloads
- **`binary:join/2`** — efficient construction of W3C Baggage/traceparent headers
- **Strict generators (EEP 70)** — fail-fast in data transformation pipelines instead of silent drops
- **Nominal types (EEP 69)** — precise Dialyzer analysis of opaque SDK types
- **JIT binary matching improvements** — faster trace context parsing
- **SSL/TLS throughput optimization** — faster OTLP exports over TLS

#### Elixir 1.19 features used by this SDK

- **Protocol dispatch type checking** — catches SDK API misuse at compile time
- **Anonymous function type inference** — better type safety in callback-heavy code (processors, samplers)
- **`Registry` key-based partitioning** — partitioned span/metric registries
- **`Base.valid16?/1`** — validate hex-encoded trace IDs and span IDs

### Comparison with opentelemetry-erlang

The existing `opentelemetry_api` on hex.pm declares `elixir: "~> 1.8"` but only CI-tests down to Elixir 1.14 / OTP 25. This project intentionally targets a higher floor because:

- It is a greenfield implementation, not a fork
- Broader compatibility would require polyfills for features listed above
- Users on older versions can continue using `opentelemetry-erlang`

### Future version policy

When a new Elixir minor version is released, the minimum version may be bumped if the new version introduces features that simplify SDK internals. Minimum version bumps follow semver — they are breaking changes and require a major version bump after `1.0.0`.

## Compliance
