# Changelog

All notable changes to `otel_semantic_conventions` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0]

### Added

- Initial hex.pm release.
- Auto-generated attribute key constants under `Otel.SemConv.Attributes.*` from [OpenTelemetry Semantic Conventions v1.40.0](https://github.com/open-telemetry/semantic-conventions/releases/tag/v1.40.0) (stable items only).
- Auto-generated metric name constants under `Otel.SemConv.Metrics.*` from the same spec version.
- Enum attributes expose a `_values()` helper returning a member-to-value map for type-safe lookup.
- Acronym preservation in module names (`HTTP`, `DB`, `URL`, `K8S`, etc.).
- Exclusion of non-BEAM-observable runtime/framework domains (`aspnetcore`, `dotnet`, `jvm`, `kestrel`, `signalr`).

[Unreleased]: https://github.com/yangbancode/otel/compare/otel_semantic_conventions-v0.1.0...HEAD
[0.1.0]: https://github.com/yangbancode/otel/releases/tag/otel_semantic_conventions-v0.1.0
