defmodule Otel.Resource do
  @moduledoc """
  SDK Resource (`resource/sdk.md` §"SDK").

  Minikube hardcodes the resource to a fixed shape. The single
  user knob is `config :otel, otp_app: :my_app` — `service.name`
  derives from the atom and `service.version` from the loaded
  application's vsn (`Application.spec(:my_app, :vsn)`, the
  same value as `mix.exs`'s `version: ...`). The `:otp_app` key
  is itself optional; without it, both attributes fall back to
  the no-config defaults below. SDK identity
  (`telemetry.sdk.*`, `deployment.environment`) is baked in at
  build time. Resource merging and Schema URL are dropped —
  power users go to `opentelemetry-erlang`. The `schema_url`
  field is preserved at the data-model level for OTLP wire
  compliance, but stays at its default `""` — there is no API
  to set it.

  ## Configuration

      # config/runtime.exs
      config :otel, otp_app: :my_app

  - `service.name` ← `Atom.to_string(:my_app)`
  - `service.version` ← `Application.spec(:my_app, :vsn)`
    (the version field of the loaded OTP application; matches
    `mix.exs`'s `version:`)

  When `:otp_app` is not configured, `service.name` falls back
  to `"unknown_service"` and `service.version` is `nil`
  (encoded as the OTLP empty `AnyValue` — same wire treatment
  in every backend, no Tempo/Mimir divergence). When
  `:otp_app` is set but the application isn't loaded yet,
  `service.version` is `nil`
  for the same reason; this is a transient state during boot
  that resolves once `Application.ensure_all_started/1`
  completes.

  ## Emitted attributes

  | Attribute | Source |
  |---|---|
  | `telemetry.sdk.name` | this SDK's `:app` key from `mix.exs` (compile-time) |
  | `telemetry.sdk.language` | `"elixir"` |
  | `telemetry.sdk.version` | this SDK's `:version` (compile-time) |
  | `deployment.environment` | `MIX_ENV` env var at SDK compile time (default `"dev"`) |
  | `service.name` | `config :otel, otp_app: :my_app` → `"my_app"` (default `"unknown_service"`) |
  | `service.version` | `Application.spec(:my_app, :vsn)` (default `nil` → empty `AnyValue` on the wire) |

  Reading at runtime keeps a single source of truth for
  `service.version` — the user's `mix.exs`. There is no `:vsn`
  knob in the SDK config, so version drift between `mix.exs`
  and the configured value is impossible. `Application.spec/2`
  is an ETS lookup (microseconds); per project policy ("no
  runtime caching") `new/0` recomputes on each call.

  `service.version` falls back to `nil` rather than being
  omitted when the application isn't loaded (or `:otp_app` is
  unset). Spec convention (Recommended, not Required) and
  `opentelemetry-erlang` would omit the key entirely; minikube
  keeps the key with a `nil` value, which the OTLP encoder
  maps to `%AnyValue{}` (oneof unset) per `common/README.md`
  L50-L51 ("empty value if supported by the language") and
  `common.proto` L29-L31 ("It is valid for all values to be
  unspecified in which case this AnyValue is considered to be
  'empty'"). Wire-level effect is uniform across backends —
  Tempo/Loki/Mimir all read this as null/absent, no
  `{label=""}` divergence.

  `deployment.environment` is captured at SDK compile time
  from `System.get_env("MIX_ENV")` directly — **not**
  `Mix.env/0`. `Mix.Tasks.Deps.Compile` wraps every dep build
  in `Mix.Dep.in_dependency` (`elixir/lib/mix/lib/mix/dep.ex`
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
  | `service.name` / `service.version` | runtime | user's `:otp_app` only set in user's runtime config; user app's vsn requires the app to be loaded |

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

  defstruct [:attributes, :schema_url]

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
  **Application** (introspection) — Construct the SDK resource.

  See module doc for the attribute set. `service.name` and
  `service.version` are read from `config :otel, :otp_app` and
  `Application.spec/2` on every call (no caching), so updates
  take effect immediately. Caller may override any field via
  `opts`.
  """
  @spec new(opts :: map()) :: t()
  def new(opts \\ %{}) do
    app = Application.get_env(:otel, :otp_app)

    defaults = %{
      attributes: %{
        "telemetry.sdk.name" => @sdk_name,
        "telemetry.sdk.language" => @sdk_language,
        "telemetry.sdk.version" => @sdk_version,
        "deployment.environment" => @deployment_environment,
        "service.name" => service_name(app),
        "service.version" => service_version(app)
      },
      schema_url: ""
    }

    struct!(__MODULE__, Map.merge(defaults, opts))
  end

  # `:otp_app` unset → fall back to `@default_service_name`
  # ("unknown_service"). When set, the atom renders as the
  # service name verbatim — matches the OTel convention of
  # `service.name = <application name>`.
  @spec service_name(app :: atom() | nil) :: String.t()
  defp service_name(nil), do: @default_service_name
  defp service_name(app) when is_atom(app), do: Atom.to_string(app)

  # `Application.spec(app, :vsn)` returns a charlist when the
  # app is loaded, `nil` otherwise. The OTLP encoder maps the
  # `nil` case to an empty `AnyValue` (see moduledoc).
  @spec service_version(app :: atom() | nil) :: String.t() | nil
  defp service_version(nil), do: nil

  defp service_version(app) when is_atom(app) do
    case Application.spec(app, :vsn) do
      nil -> nil
      vsn -> List.to_string(vsn)
    end
  end
end
