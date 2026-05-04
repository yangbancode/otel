defmodule Otel.Resource do
  @moduledoc """
  SDK Resource (`resource/sdk.md` §"SDK").

  Minikube hardcodes the resource to a fixed shape. There is no
  user config knob — `service.name` and `service.version` come
  from the standard Mix release env vars (`RELEASE_NAME`,
  `RELEASE_VSN`) at runtime, automatically set by Mix release
  boot scripts. SDK identity (`telemetry.sdk.*`,
  `deployment.environment`) is baked in at build time. Resource
  merging and Schema URL are dropped — power users go to
  `opentelemetry-erlang`. The `schema_url` field is preserved at
  the data-model level for OTLP wire compliance, but stays at
  its default `""` — there is no API to set it.

  ## Configuration

  No `config :otel, ...` knob for resource. In production with
  `mix release`, `RELEASE_NAME` and `RELEASE_VSN` are exported
  by the boot script (`bin/<app> start`) so `service.name` and
  `service.version` are populated automatically.

  Outside a release (dev `iex -S mix`, `mix test`), the env
  vars are unset and `service.name` falls back to
  `"unknown_service"`; `service.version` is `nil` (encoded as
  the OTLP empty `AnyValue` — same wire treatment in every
  backend, no Tempo/Mimir divergence). Callers who need a
  specific identity in those contexts can export the env vars
  manually:

      RELEASE_NAME=my_app RELEASE_VSN=0.1.0 iex -S mix

  ## Emitted attributes

  | Attribute | Source |
  |---|---|
  | `telemetry.sdk.name` | this SDK's `:app` from `mix.exs` (compile-time) |
  | `telemetry.sdk.language` | `"elixir"` |
  | `telemetry.sdk.version` | this SDK's `:version` (compile-time) |
  | `deployment.environment` | `MIX_ENV` env var at SDK compile time (default `"dev"`) |
  | `service.name` | `RELEASE_NAME` (default `"unknown_service"`) |
  | `service.version` | `RELEASE_VSN` (default `nil` → empty `AnyValue` on the wire) |

  Reading `RELEASE_NAME` / `RELEASE_VSN` at runtime mirrors
  `opentelemetry-erlang`'s `otel_resource_detector.erl:215-234`
  (`find_release/0`). Both env vars are exported by Mix
  release's generated boot script (`elixir/lib/mix/lib/mix/tasks/release.init.ex`
  L103-L106). Compile-time read would always see them as
  `nil` because the SDK's dep compilation phase predates any
  release boot.

  `service.version` falls back to `nil` rather than being
  omitted when `RELEASE_VSN` is unset. Spec convention
  (Recommended, not Required) and `opentelemetry-erlang` would
  omit the key entirely; minikube keeps the key with a `nil`
  value, which the OTLP encoder maps to `%AnyValue{}`
  (oneof unset) per `common/README.md` L50-L51 ("empty value if
  supported by the language") and `common.proto` L29-L31
  ("It is valid for all values to be unspecified in which case
  this AnyValue is considered to be 'empty'"). Wire-level effect
  is uniform across backends — Tempo/Loki/Mimir all read this
  as null/absent, no `{label=""}` divergence.

  `deployment.environment` is captured at SDK compile time from
  `System.get_env("MIX_ENV")` directly — **not** `Mix.env/0`.
  `Mix.Tasks.Deps.Compile` wraps every dep build in
  `Mix.Dep.in_dependency` (`elixir/lib/mix/lib/mix/dep.ex`
  L246-L270) which forces `Mix.env(:prod)` for the dep's
  compilation context regardless of the consuming app's
  `MIX_ENV`, so a `Mix.env()` call inside this module would
  always evaluate to `:prod`. Reading `MIX_ENV` from the OS
  environment bypasses that override — Mix mutates only its
  internal `Mix.State` (`elixir/lib/mix/lib/mix/state.ex`
  L65-L89), never the env var.

  ## Read-time per attribute

  | Attribute | Read time | Why |
  |---|---|---|
  | `telemetry.sdk.*` | compile | dep mix.exs config only available during build |
  | `deployment.environment` | compile | `MIX_ENV` is build-time intent; release boot doesn't export it |
  | `service.name` / `service.version` | runtime | `RELEASE_NAME`/`VSN` are set by release boot script, not at build |

  ## References

  - OTel Resource SDK: `opentelemetry-specification/specification/resource/sdk.md`
  - OTLP proto Resource: `opentelemetry-proto/opentelemetry/proto/resource/v1/resource.proto`
  - Semantic Conventions §service: `semantic-conventions/docs/resource/service.md`
  """

  use Otel.Common.Types

  @type t :: %__MODULE__{
          attributes: %{String.t() => primitive_any()},
          schema_url: String.t()
        }

  defstruct attributes: %{}, schema_url: ""

  # SDK identity captured from the SDK's own `mix.exs` at
  # build time — these values describe `:otel`, not the
  # consuming application.
  @sdk_name Mix.Project.config()[:app] |> Atom.to_string()
  @sdk_language "elixir"
  @sdk_version Mix.Project.config()[:version]
  @default_service_name "unknown_service"
  # Bypasses Mix.Dep.in_dependency's :prod override on `Mix.env()`
  # (see moduledoc). `System.get_env/2` only falls back on `nil`,
  # so an exotic `MIX_ENV=""` builds carry the empty string —
  # accepted edge case.
  @deployment_environment System.get_env("MIX_ENV", "dev")

  @doc """
  **Application** (introspection) — Returns the SDK's resource.

  See module doc for the attribute set. `service.name` and
  `service.version` are read from `RELEASE_NAME` / `RELEASE_VSN`
  env vars on every call (no caching), so updates take effect
  immediately.
  """
  @spec build() :: t()
  def build do
    %__MODULE__{
      attributes: %{
        "telemetry.sdk.name" => @sdk_name,
        "telemetry.sdk.language" => @sdk_language,
        "telemetry.sdk.version" => @sdk_version,
        "deployment.environment" => @deployment_environment,
        "service.name" => System.get_env("RELEASE_NAME", @default_service_name),
        "service.version" => System.get_env("RELEASE_VSN")
      }
    }
  end
end
