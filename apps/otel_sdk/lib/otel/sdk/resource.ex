defmodule Otel.SDK.Resource do
  @moduledoc """
  Immutable representation of the entity producing telemetry.

  A Resource is a list of key-value attributes describing the service
  (e.g., service.name, host.name) and an optional Schema URL. Resources
  are associated with TracerProvider/MeterProvider at creation time.
  """

  @type t :: %__MODULE__{
          attributes: [Otel.API.Common.Attribute.t()],
          schema_url: String.t()
        }

  defstruct attributes: [], schema_url: ""

  @doc """
  Creates a new Resource from attributes and optional schema_url.

  Accepts either a pre-built list of `Otel.API.Common.Attribute.t()`
  structs, or a plain map/keyword of native Elixir values. Native
  values are coerced into `Otel.API.Common.AnyValue` by inferring
  the variant from the value's Elixir type, since `create/2` is a
  public constructor at the system boundary.
  """
  @spec create(
          attributes ::
            [Otel.API.Common.Attribute.t()]
            | %{String.t() => term()}
            | [{String.t(), term()}],
          schema_url :: String.t()
        ) :: t()
  def create(attributes, schema_url \\ "") do
    attrs = to_attribute_list(attributes)
    %__MODULE__{attributes: attrs, schema_url: schema_url}
  end

  @doc """
  Merges two Resources.

  The `updating` resource's attribute values take precedence when keys
  overlap. Schema URL rules:
  - If old has empty schema_url -> use updating's
  - If updating has empty schema_url -> use old's
  - If both match -> use that URL
  - If both differ -> empty (merge conflict)
  """
  @spec merge(old :: t(), updating :: t()) :: t()
  def merge(%__MODULE__{} = old, %__MODULE__{} = updating) do
    merged_attributes = merge_attributes(old.attributes, updating.attributes)
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
        put_attribute(
          attrs,
          Otel.API.Common.Attribute.new(
            "service.name",
            Otel.API.Common.AnyValue.string(String.trim(service_name))
          )
        )
      else
        attrs
      end

    %__MODULE__{attributes: attrs, schema_url: ""}
  end

  # --- Private ---

  @spec to_attribute_list(
          input ::
            [Otel.API.Common.Attribute.t()]
            | %{String.t() => term()}
            | [{String.t(), term()}]
        ) :: [Otel.API.Common.Attribute.t()]
  defp to_attribute_list([%Otel.API.Common.Attribute{} | _] = list), do: list
  defp to_attribute_list([]), do: []

  defp to_attribute_list(list) when is_list(list) do
    Enum.map(list, fn {key, value} ->
      Otel.API.Common.Attribute.new(to_string(key), coerce_any_value(value))
    end)
  end

  defp to_attribute_list(map) when is_map(map) do
    Enum.map(map, fn {key, value} ->
      Otel.API.Common.Attribute.new(to_string(key), coerce_any_value(value))
    end)
  end

  @spec coerce_any_value(value :: term()) :: Otel.API.Common.AnyValue.t()
  defp coerce_any_value(%Otel.API.Common.AnyValue{} = v), do: v
  defp coerce_any_value(v) when is_binary(v), do: Otel.API.Common.AnyValue.string(v)
  defp coerce_any_value(v) when is_boolean(v), do: Otel.API.Common.AnyValue.bool(v)
  defp coerce_any_value(v) when is_integer(v), do: Otel.API.Common.AnyValue.int(v)
  defp coerce_any_value(v) when is_float(v), do: Otel.API.Common.AnyValue.double(v)
  defp coerce_any_value(nil), do: Otel.API.Common.AnyValue.empty()

  defp coerce_any_value(v) when is_list(v) do
    Otel.API.Common.AnyValue.array(Enum.map(v, &coerce_any_value/1))
  end

  @spec merge_attributes(
          old :: [Otel.API.Common.Attribute.t()],
          updating :: [Otel.API.Common.Attribute.t()]
        ) :: [Otel.API.Common.Attribute.t()]
  defp merge_attributes(old, updating) do
    Enum.reduce(updating, old, fn attr, acc -> put_attribute(acc, attr) end)
  end

  @spec put_attribute(
          list :: [Otel.API.Common.Attribute.t()],
          attr :: Otel.API.Common.Attribute.t()
        ) :: [Otel.API.Common.Attribute.t()]
  defp put_attribute(list, %Otel.API.Common.Attribute{key: key} = attr) do
    case Enum.any?(list, fn %Otel.API.Common.Attribute{key: k} -> k == key end) do
      true ->
        Enum.map(list, fn
          %Otel.API.Common.Attribute{key: ^key} -> attr
          other -> other
        end)

      false ->
        list ++ [attr]
    end
  end

  @spec merge_schema_url(old :: String.t(), updating :: String.t()) :: String.t()
  defp merge_schema_url("", updating), do: updating
  defp merge_schema_url(old, ""), do: old
  defp merge_schema_url(same, same), do: same
  defp merge_schema_url(_old, _updating), do: ""

  @spec parse_resource_attributes(value :: String.t() | nil) :: [Otel.API.Common.Attribute.t()]
  defp parse_resource_attributes(nil), do: []
  defp parse_resource_attributes(""), do: []

  defp parse_resource_attributes(value) do
    value
    |> String.split(",")
    |> Enum.reduce([], fn pair, acc ->
      case String.split(String.trim(pair), "=", parts: 2) do
        [key, val] when key != "" ->
          attr =
            Otel.API.Common.Attribute.new(
              URI.decode(String.trim(key)),
              Otel.API.Common.AnyValue.string(URI.decode(String.trim(val)))
            )

          put_attribute(acc, attr)

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
