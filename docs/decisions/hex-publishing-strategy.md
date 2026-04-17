# hex.pm Publishing Strategy

## Question

How to publish the umbrella apps to hex.pm? Specifically: package naming, version policy, release tagging, inter-app dependencies, and what triggers a publish.

## Decision

### One Hex Package per Umbrella App

Each `apps/*` umbrella app publishes as its own hex package. Hex has no umbrella concept — the unit of distribution is one OTP application. Five eventual packages, all using their `app:` atom verbatim as the hex package name:

| Umbrella App | Hex Package |
|---|---|
| `otel_api` | `otel_api` |
| `otel_sdk` | `otel_sdk` |
| `otel_exporter_otlp` | `otel_exporter_otlp` |
| `otel_logger_handler` | `otel_logger_handler` |
| `otel_semantic_conventions` | `otel_semantic_conventions` |

The umbrella root is never published. Root [`mix.exs`](../../mix.exs) carries no `package` metadata.

### Independent Semver per Package

Each package versions independently. Pinning all five packages to one global version would force needless republishes whenever any one app changes. Cross-app dependencies (e.g., `otel_sdk` depending on `otel_api`) are declared with hex constraints once both are published:

```elixir
deps: [{:otel_api, "~> 0.1"}]
```

`otel_semantic_conventions` has no dependency on other umbrella apps (only generates static modules), making it the safest first publish for validating the pipeline.

### Initial Version: 0.1.0

The first published version is `0.1.0`, not `1.0.0`. Reasons:

- The package surface (function naming, helper-map shape, module grouping under `Otel.SemConv.Attributes.*` / `Otel.SemConv.Metrics.*`) may need iteration before stabilizing
- Semver `0.x` signals "API may change in minor releases" — room to fix mistakes without burning a major version
- `1.0.0` is reserved for when the surface is stable enough to commit to full backward-compat guarantees

### Package Version vs SemConv Spec Version

Package version and OTel SemConv spec version are decoupled. SemConv v1.40.0 may back package versions `0.1.0`, `0.1.1`, `0.2.0`, etc. — those increments reflect *package-level* changes (template fixes, helper additions, refactors), not spec changes.

Mapping is documented per release in the package README and CHANGELOG:

| Package Version | SemConv Spec |
|---|---|
| `0.1.x` | v1.40.0 |
| `0.2.x` | (next spec bump) |

When the SemConv spec bumps, regenerate and choose the package version increment based on user impact (minor for additions, major for stable-item removals/renames — rare per OTel stability policy).

### Tag Format: `<package>-v<version>`

Release tags follow `<package>-v<version>`:

- `otel_semantic_conventions-v0.1.0`
- `otel_api-v0.3.2`

A bare `v0.1.0` tag would be ambiguous across five independently-versioned packages. The prefixed form is greppable and lets per-package CI workflows match by tag pattern.

### Release Trigger: GitHub Release published

The publish workflow triggers on `release.published`, not raw tag pushes:

```yaml
on:
  release:
    types: [published]
```

Creating a Release in GitHub UI is an explicit, intentional action — harder to trigger by accident than a tag push. Release notes also serve as the human-readable summary that complements CHANGELOG.

### Per-Package Files Layout

Each app directory holds its own publishing assets:

```
apps/otel_semantic_conventions/
  mix.exs           # package metadata + ex_doc config
  README.md         # what hex.pm displays
  CHANGELOG.md      # version history
  LICENSE           # Unlicense (per-package copy)
  lib/              # source
```

The hex tarball is built from the app directory. Umbrella root [`README.md`](../../README.md) and [`docs/`](../) are **not** included — the per-app README links back to GitHub for full-SDK context (decisions, compliance, tech-spec).

### License Files: Per-Package Copies

`LICENSE` is copied into each published app directory rather than referenced via `../../` paths in `package.files`. Hex's default `package.files` only picks up `LICENSE*` patterns relative to the app dir, the file is short and stable, and per-app copies make `mix hex.build` straightforward.

All packages declare `licenses: ["Unlicense"]` (public domain dedication via [unlicense.org](https://unlicense.org/)) and ship a per-app `LICENSE` file. The umbrella root has no shared `LICENSE` — each app is self-contained so the hex tarball carries the license it needs without cross-directory references. `NOTICE` files are added per-app only when an app vendors third-party content with attribution requirements; currently only `otel_exporter_otlp` carries one for the bundled opentelemetry-proto generated code.

### CI Changes

Two CI changes accompany this strategy:

1. **Main [`ci.yml`](../../.github/workflows/ci.yml)**: add per-app `mix hex.build` step. Catches missing metadata or wrong `files` configuration at PR time, not at release time.

2. **New `publish.yml`**: triggers on `release.published`. Steps:
   - Parse `<package>` + `<version>` from the release tag
   - Verify `apps/<package>/mix.exs` version matches the tag version; fail if not (catches mistyped tags)
   - Run the full quality gate (format / compile / test / credo / dialyzer)
   - `cd apps/<package> && mix hex.publish --yes` using `HEX_API_KEY`

`HEX_API_KEY` is a hex.pm API key with **API: Read** + **API: Write** permissions, scoped to the user's personal repository (no `All Repositories` since there is no private hex organization).

### Publishing Order

1. `otel_semantic_conventions` (this initiative) — zero inter-app dependencies, validates the pattern
2. `otel_api` — depended on by all signal SDKs
3. `otel_sdk`
4. `otel_exporter_otlp`
5. `otel_logger_handler`

Each subsequent app reuses the mix.exs metadata pattern, README structure, and `publish.yml` workflow established here.

## Compliance

No spec compliance items — this is an engineering distribution decision.
