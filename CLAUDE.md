# CLAUDE.md

## Primary sources

- `references/opentelemetry-specification/` — OTel spec (authoritative)
- `references/opentelemetry-erlang/` — Erlang reference impl (cross-check)
- `references/opentelemetry-proto/`, `references/w3c-trace-context/`,
  `references/w3c-baggage/`, `references/semantic-conventions/` — wire formats
- `references/otp/` — Erlang/OTP stdlib source (pinned to the
  runtime tag declared in `.mise.toml`; used when the correct behaviour
  of `:logger`, `:persistent_term`, `gen_statem`, etc. must be verified
  against what the runtime actually does rather than what docs claim)

## Architecture docs

- [docs/architecture/](docs/architecture/) — BEAM-specific design
  decisions that aren't recoverable from code alone (provider
  dispatch, type representation, error handling policy,
  sync/async instrument shape, `with_span` lifecycle ownership).

Per-module rationale lives in each module's `@moduledoc`
(`## Design notes` section where applicable). Spec compliance is
verified against `references/` directly, **not against AI
training-data knowledge of the spec** — see `.claude/rules/workflow.md`
§ Spec sources for the references-only mandate and § Spec submodule
update for the re-verification workflow when the pin advances.

## Rules

- [Workflow](.claude/rules/workflow.md)
- [Git Conventions](.claude/rules/git-conventions.md)
- [Code Conventions](.claude/rules/code-conventions.md)
- [Documentation](.claude/rules/documentation.md)