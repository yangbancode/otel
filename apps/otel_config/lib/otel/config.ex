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

  ## Public API

  | Function | Role |
  |---|---|
  | `config_file_set?/0` | **SDK** (wiring) — `OTEL_CONFIG_FILE` set + non-empty? |
  | `load!/0` | **SDK** (wiring) — run the full Parse + Create pipeline |

  ## References

  - Spec: `opentelemetry-specification/specification/configuration/sdk.md`
  - Schema: `opentelemetry-configuration/opentelemetry_configuration.json`
    (pinned at v1.0.0)
  - Examples: `references/opentelemetry-configuration/examples/`
  """

  @env_var "OTEL_CONFIG_FILE"

  @doc """
  Returns `true` when `OTEL_CONFIG_FILE` is set and non-empty.

  Used by `Otel.SDK.Application.start/2` to decide whether to route
  through the declarative-config pipeline or fall back to the
  env-var path (`Otel.SDK.Config`).
  """
  @spec config_file_set?() :: boolean()
  def config_file_set? do
    case System.get_env(@env_var) do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  @doc """
  Reads the file path in `OTEL_CONFIG_FILE` and runs the full
  declarative-config pipeline:

      File.read!(path)
      |> Otel.Config.Substitution.substitute!()
      |> Otel.Config.Parser.parse_string!()
      |> Otel.Config.Schema.validate!()
      |> Otel.Config.Composer.compose!()

  Returns the per-pillar config map shape that
  `Otel.SDK.Config.{trace,metrics,logs}/0` produces, so the wiring
  layer can hand the result straight to provider `start_link/1`.

  Raises if `OTEL_CONFIG_FILE` is unset, the file is missing /
  unreadable, the YAML is malformed, the model fails schema
  validation, or composition encounters an unsupported feature
  (e.g. `pull` MetricReader, `otlp_grpc`).
  """
  @spec load!() :: %{trace: map(), metrics: map(), logs: map()}
  def load! do
    path =
      System.get_env(@env_var) ||
        raise ArgumentError, "#{@env_var} is not set"

    raw = File.read!(path)
    model = raw |> Otel.Config.Substitution.substitute!() |> Otel.Config.Parser.parse_string!()
    Otel.Config.Schema.validate!(model)
    Otel.Config.Composer.compose!(model)
  end
end
