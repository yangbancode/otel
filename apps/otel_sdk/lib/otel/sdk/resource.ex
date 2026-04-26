defmodule Otel.SDK.Resource do
  @moduledoc """
  Immutable representation of the entity producing telemetry
  (`resource/sdk.md` §"SDK").

  A Resource is a set of key-value attributes describing the service
  (e.g., service.name, host.name) and an optional Schema URL. Resources
  are associated with TracerProvider/MeterProvider at creation time.

  ## References

  - OTel Resource SDK: `opentelemetry-specification/specification/resource/sdk.md`
  - OTLP proto Resource: `opentelemetry-proto/opentelemetry/proto/resource/v1/resource.proto`
  """

  use Otel.API.Common.Types

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
  Returns the SDK-provided default Resource.

  Includes telemetry.sdk.* and service.name attributes.
  """
  @spec default() :: t()
  def default do
    create(%{
      "telemetry.sdk.name" => "otel",
      "telemetry.sdk.language" => "elixir",
      "telemetry.sdk.version" => sdk_version(),
      "service.name" => "unknown_service"
    })
  end

  # --- Private ---

  @spec merge_schema_url(old :: String.t(), updating :: String.t()) :: String.t()
  defp merge_schema_url("", updating), do: updating
  defp merge_schema_url(old, ""), do: old
  defp merge_schema_url(same, same), do: same
  defp merge_schema_url(_old, _updating), do: ""

  @spec sdk_version() :: String.t()
  defp sdk_version do
    Application.spec(:otel_sdk, :vsn) |> to_string()
  end
end
