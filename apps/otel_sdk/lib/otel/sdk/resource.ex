defmodule Otel.SDK.Resource do
  @moduledoc """
  Immutable representation of the entity producing telemetry.

  A Resource is a set of key-value attributes describing the service
  (e.g., service.name, host.name) and an optional Schema URL. Resources
  are associated with TracerProvider/MeterProvider at creation time.
  """

  @type t :: %__MODULE__{
          attributes: %{String.t() => String.t() | integer() | float() | boolean()},
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

  @doc """
  Creates a Resource from OTEL_RESOURCE_ATTRIBUTES and OTEL_SERVICE_NAME
  environment variables.

  Format: `key1=value1,key2=value2` (values are percent-encoded).
  OTEL_SERVICE_NAME overrides service.name if set.
  """
  @spec from_env() :: t()
  def from_env do
    attrs = parse_resource_attributes(System.get_env("OTEL_RESOURCE_ATTRIBUTES"))
    service_name = System.get_env("OTEL_SERVICE_NAME")

    attrs =
      if service_name != nil and service_name != "" do
        Map.put(attrs, "service.name", String.trim(service_name))
      else
        attrs
      end

    create(attrs)
  end

  # --- Private ---

  @spec merge_schema_url(old :: String.t(), updating :: String.t()) :: String.t()
  defp merge_schema_url("", updating), do: updating
  defp merge_schema_url(old, ""), do: old
  defp merge_schema_url(same, same), do: same
  defp merge_schema_url(_old, _updating), do: ""

  @spec parse_resource_attributes(value :: String.t() | nil) :: map()
  defp parse_resource_attributes(nil), do: %{}
  defp parse_resource_attributes(""), do: %{}

  defp parse_resource_attributes(value) do
    value
    |> String.split(",")
    |> Enum.reduce(%{}, fn pair, acc ->
      case String.split(String.trim(pair), "=", parts: 2) do
        [key, val] when key != "" ->
          Map.put(
            acc,
            Otel.API.Baggage.Percent.decode(String.trim(key)),
            Otel.API.Baggage.Percent.decode(String.trim(val))
          )

        _ ->
          acc
      end
    end)
  end

  @spec sdk_version() :: String.t()
  defp sdk_version do
    Application.spec(:otel_sdk, :vsn) |> to_string()
  end
end
