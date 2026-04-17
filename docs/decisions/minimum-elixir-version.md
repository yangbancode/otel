# Minimum Elixir Version

## Question

What Elixir / Erlang/OTP version does this project target, and should it declare a floor + test a matrix or pin a single combination?

## Decision

### Minimum Versions

- **Elixir**: `~> 1.18` (pinned and CI-tested on 1.18.4)
- **Erlang/OTP**: `~> 26.0` (pinned and CI-tested on 26.2.5.19)

These match `.mise.toml` for local development and `.github/workflows/ci.yml` for CI. All six `mix.exs` files in the umbrella declare `elixir: "~> 1.18"`.

### Why these versions specifically

**Elixir 1.18** — the type checker becomes practically useful at this version. It validates `@spec` annotations against implementation bodies at compile time and warns on type violations. Since this codebase follows a convention of full `@spec` coverage on every `def` and `defp` (see [code-conventions.md](../../.claude/rules/code-conventions.md)), the 1.18 checker gives the specs real teeth — particularly valuable for catching AI-generated code drift against declared types.

**Erlang/OTP 26** — OTP 26 made secure-by-default changes to `:ssl` (verify_peer, hostname check, safer cipher defaults). The OTLP exporter's TLS setup currently passes these options explicitly, but OTP 26+ as a floor means a future simplification (relying on defaults) is not a breaking change.

Neither constraint is driven by a specific runtime feature in use today — the 1.18 code could technically run on 1.11, and OTP 26 code on OTP 22. The constraints are forward-looking engineering choices.

### Single version, no matrix

The project pins exactly one Elixir × OTP combination rather than declaring a range and testing a matrix.

Reasons:

- GitHub Actions minutes are a practical constraint for a single-maintainer project. A 5-job matrix multiplies compute cost without proportionally increasing confidence when no runtime features are version-sensitive.
- "Declared minimum" and "tested minimum" collapse into the same value — no claims to support a version that CI has never seen pass.
- Upgrading is a mechanical process: bump `.mise.toml`, `ci.yml` env vars, and the `~>` constraints in six `mix.exs` files together.

Hex's `~> 1.18` constraint still lets users install on Elixir 1.19+ (semver-compatible range), so downstream developers running a newer Elixir can use the package; that scenario just isn't part of this project's CI guarantee.

### Comparison with opentelemetry-erlang

`opentelemetry_api` on hex.pm declares `elixir: "~> 1.8"` but CI-tests only down to Elixir 1.14 / OTP 25. Their "declared" and "tested" minimums diverge intentionally, betting that most 1.8+ users will be close enough.

This project takes the opposite posture: **declared = tested**. The floor is whatever CI exercises, nothing lower.

### Future version policy

- **Tracking new minor releases**: When a new Elixir or OTP minor is stable for ~1 quarter, the project may bump the pin (`.mise.toml`, `ci.yml`, `mix.exs`). This is a chore-level change.
- **Floor bumps** (e.g. Elixir 1.18 → 1.19 as the new minimum) are **breaking changes** for hex consumers and, after 1.0.0, require a major version bump of every affected package.
- **Floor drops** (lowering the minimum) are rare; they need either explicit code changes that work on older versions or evidence from CI matrix testing that the older versions pass.

## Compliance

No spec compliance items — this is an engineering configuration decision.
