defmodule Otel.Config do
  @moduledoc """
  Declarative configuration for the OpenTelemetry Elixir SDK
  (`OTEL_CONFIG_FILE`).

  Implements the spec-defined declarative configuration mechanism
  (`opentelemetry-specification/specification/configuration/sdk.md`,
  Status: Stable as of v1.55.0) — load a YAML file, validate it
  against the v1.0.0 JSON Schema published in
  `references/opentelemetry-configuration/`, and produce the same
  per-pillar provider config maps that `Otel.SDK.Config` produces
  from env vars.

  This app is **opt-in**. SDK users who configure via Mix Config or
  `OTEL_*` env vars do not need to add it. Users who want to
  configure the SDK from a YAML file:

  ```elixir
  # mix.exs
  defp deps do
    [
      {:otel_sdk, "..."},
      {:otel_config, "..."}    # ← add this
    ]
  end
  ```

  Then set `OTEL_CONFIG_FILE=/path/to/config.yaml` and boot the
  application — `Otel.SDK.Application.start/2` detects the env var
  + loaded module and routes through this app.

  ## Spec compliance scope

  Only **Stable** schema types are honored. Properties marked
  `*/development` (per the schema's
  [versioning policy](https://github.com/open-telemetry/opentelemetry-configuration/blob/v1.0.0/VERSIONING.md))
  emit a warning and are ignored — matches our project policy
  (CLAUDE.md / `.claude/rules/workflow.md`) of not adopting
  Development-status spec features.

  Stable interfaces implemented:

  - `Parse` (`configuration/sdk.md` §SDK operations) — YAML →
    in-memory model
  - `Create` (`configuration/sdk.md` §SDK operations) — in-memory
    model → SDK provider configs
  - Env var substitution (`configuration/data-model.md` §Environment
    variable substitution) — `${VAR}` and `${VAR:-default}`
  - Kill switch (`sdk-environment-variables.md` L332-L337) — when
    `OTEL_CONFIG_FILE` is set, **all other `OTEL_*` env vars MUST
    be ignored** except those used in substitution

  Not implemented (spec Status: Development):

  - `ConfigProvider` interface (runtime introspection of in-memory
    model)
  - `PluginComponentProvider` extension mechanism
  - Programmatic customization of `Create` output

  ## Implementation status

  This module is currently a placeholder. The implementation lands
  across follow-up PRs:

  1. ~~app scaffold~~ ← *this PR*
  2. YAML parser
  3. JSON Schema validator (against v1.0.0 schema)
  4. Env var substitution
  5. Composer (in-memory model → provider configs)
  6. End-to-end wiring in `Otel.SDK.Application`

  ## References

  - Spec: `opentelemetry-specification/specification/configuration/sdk.md`
  - Schema: `opentelemetry-configuration/opentelemetry_configuration.json`
    (pinned at v1.0.0)
  - Examples: `references/opentelemetry-configuration/examples/`
  """
end
