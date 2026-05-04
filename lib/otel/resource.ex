defmodule Otel.Resource do
  @moduledoc """
  SDK Resource (`resource/sdk.md` §"SDK").

  Minikube hardcodes the resource to a fixed shape — the only
  user knob is `:otp_app`, which derives `service.name` and
  `service.version`. Resource merging is dropped (use
  `opentelemetry-erlang` if you need it). The `schema_url`
  field is preserved at the data-model level for OTLP wire
  compliance, but stays at its default `""` — there is no API
  to set it.

  ## Configuration

      config :otel, otp_app: :my_app

  Without `:otp_app`, `service.name` falls back to
  `"unknown_service"` (spec MUST per `resource/sdk.md`
  §"Service") and `service.version` is omitted entirely.

  ## Emitted attributes

  | Attribute | Source |
  |---|---|
  | `telemetry.sdk.name` | this SDK's `:app` from `mix.exs` (compile-time) |
  | `telemetry.sdk.language` | `"elixir"` |
  | `telemetry.sdk.version` | this SDK's `:version` (compile-time) |
  | `deployment.environment` | `Mix.env()` (compile-time) |
  | `service.name` | `:otp_app` config or `"unknown_service"` |
  | `service.version` | `Application.spec(:otp_app, :vsn)` (key omitted when unavailable) |

  `service.version` is a Recommended (not Required) attribute
  per `semantic-conventions/docs/resource/service.md` L67;
  spec defines no `unknown_version` fallback, so the key is
  dropped when the value can't be determined — matching
  `opentelemetry-erlang`'s `otel_resource_detector.erl:297-307`
  release-version handling.

  `deployment.environment` is frozen at SDK compile time —
  staging and prod releases both built with `MIX_ENV=prod`
  report `"prod"`. Acceptable trade-off for the minikube
  config surface; users wanting per-deploy granularity should
  use `opentelemetry-erlang`.

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
  @deployment_environment Mix.env() |> Atom.to_string()

  @doc """
  **Application** (introspection) — Returns the SDK's resource.

  See module doc for the attribute set. Read on demand by each
  pillar's emit / collect / export path; no caching, so a
  test-time `Application.put_env(:otel, :otp_app, :other)`
  takes effect immediately for every subsequent call.
  """
  @spec build() :: t()
  def build do
    otp_app = Application.get_env(:otel, :otp_app)

    %__MODULE__{
      attributes:
        %{
          "telemetry.sdk.name" => @sdk_name,
          "telemetry.sdk.language" => @sdk_language,
          "telemetry.sdk.version" => @sdk_version,
          "deployment.environment" => @deployment_environment
        }
        |> put_service_name(otp_app)
        |> put_service_version(otp_app)
    }
  end

  # --- Private ---

  @spec put_service_name(
          attrs :: %{String.t() => primitive_any()},
          otp_app :: atom() | nil
        ) :: %{String.t() => primitive_any()}
  defp put_service_name(attrs, nil),
    do: Map.put(attrs, "service.name", @default_service_name)

  defp put_service_name(attrs, otp_app),
    do: Map.put(attrs, "service.name", Atom.to_string(otp_app))

  @spec put_service_version(
          attrs :: %{String.t() => primitive_any()},
          otp_app :: atom() | nil
        ) :: %{String.t() => primitive_any()}
  defp put_service_version(attrs, nil), do: attrs

  defp put_service_version(attrs, otp_app) do
    case Application.spec(otp_app, :vsn) do
      nil -> attrs
      vsn -> Map.put(attrs, "service.version", to_string(vsn))
    end
  end
end
