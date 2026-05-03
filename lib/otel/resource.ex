defmodule Otel.Resource do
  @moduledoc """
  Immutable representation of the entity producing telemetry
  (`resource/sdk.md` §"SDK").

  A Resource is a set of key-value attributes describing the service
  (e.g., service.name, host.name) and an optional Schema URL.
  Each pillar entry point (`Otel.Trace`, `Otel.Logs.LoggerProvider`,
  `Otel.Metrics.MeterProvider`) reads the resource via
  `from_app_env/0` on demand — no boot-time snapshot.

  ## Default Resource

  `default/0` returns the SDK-provided base
  (`telemetry.sdk.{name,language,version}`) plus a fallback
  `service.name` of `"unknown_service"`. The SDK reads no
  OS environment variables; user attributes are configured via
  `config :otel, resource: %{...}` (a map, not a struct).
  `from_app_env/0` merges the user's map onto the default base.

  Bridge OS env vars (`OTEL_SERVICE_NAME` /
  `OTEL_RESOURCE_ATTRIBUTES`) from `runtime.exs` (Phoenix
  `PHX_SERVER` pattern):

      # config/runtime.exs
      import Config

      config :otel,
        resource: %{
          "service.name" => System.get_env("OTEL_SERVICE_NAME") || "my_app"
        }

  ## References

  - OTel Resource SDK: `opentelemetry-specification/specification/resource/sdk.md`
  - OTLP proto Resource: `opentelemetry-proto/opentelemetry/proto/resource/v1/resource.proto`
  """

  use Otel.Common.Types

  @type t :: %__MODULE__{
          attributes: %{String.t() => primitive_any()},
          schema_url: String.t()
        }

  defstruct attributes: %{}, schema_url: ""

  @doc """
  Creates a new Resource from attributes and optional schema_url.
  """
  @spec create(
          attributes :: %{String.t() => term()} | [{String.t(), term()}],
          schema_url :: String.t()
        ) :: t()
  def create(attributes, schema_url \\ "") do
    attrs =
      case attributes do
        map when is_map(map) -> map
        list when is_list(list) -> Map.new(list)
      end

    %__MODULE__{attributes: attrs, schema_url: schema_url}
  end

  @doc """
  Merges two Resources.

  The `updating` resource's attribute values take precedence when keys
  overlap. Schema URL rules:
  - If old has empty schema_url → use updating's
  - If updating has empty schema_url → use old's
  - If both match → use that URL
  - If both differ → empty (merge conflict)
  """
  @spec merge(old :: t(), updating :: t()) :: t()
  def merge(%__MODULE__{} = old, %__MODULE__{} = updating) do
    merged_attributes = Map.merge(old.attributes, updating.attributes)
    merged_schema_url = merge_schema_url(old.schema_url, updating.schema_url)
    %__MODULE__{attributes: merged_attributes, schema_url: merged_schema_url}
  end

  @doc """
  Returns the resolved boot-time Resource — `default/0` merged
  with the user's `config :otel, resource: %{...}` map.

  Called once per provider at `init/0` time. User attributes
  take precedence on key conflicts; the `service.name` fallback
  applies only when the user supplies no value.
  """
  @spec from_app_env() :: t()
  def from_app_env do
    user_attrs = Application.get_env(:otel, :resource, %{})
    merge(default(), create(user_attrs))
  end

  @doc """
  Returns the SDK-provided default Resource.

  Includes `telemetry.sdk.*` attributes plus a fallback
  `service.name` of `"unknown_service"`. The SDK reads no
  OS environment variables — bridge `OTEL_SERVICE_NAME` /
  `OTEL_RESOURCE_ATTRIBUTES` from `runtime.exs` (see module doc).
  """
  @spec default() :: t()
  def default do
    attributes = %{
      "telemetry.sdk.name" => "otel",
      "telemetry.sdk.language" => "elixir",
      "telemetry.sdk.version" => sdk_version(),
      "service.name" => "unknown_service"
    }

    %__MODULE__{attributes: attributes, schema_url: ""}
  end

  # --- Private ---

  @spec merge_schema_url(old :: String.t(), updating :: String.t()) :: String.t()
  defp merge_schema_url("", updating), do: updating
  defp merge_schema_url(old, ""), do: old
  defp merge_schema_url(same, same), do: same
  defp merge_schema_url(_old, _updating), do: ""

  @spec sdk_version() :: String.t()
  defp sdk_version do
    Application.spec(:otel, :vsn) |> to_string()
  end
end
