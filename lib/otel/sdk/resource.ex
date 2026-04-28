defmodule Otel.SDK.Resource do
  @moduledoc """
  Immutable representation of the entity producing telemetry
  (`resource/sdk.md` §"SDK").

  A Resource is a set of key-value attributes describing the service
  (e.g., service.name, host.name) and an optional Schema URL. Resources
  are associated with TracerProvider/MeterProvider at creation time.

  ## Environment-derived defaults

  `default/0` reads two environment variables per spec
  `resource/sdk.md` L172-L193 and merges their attributes
  on top of the SDK-provided base
  (`telemetry.sdk.{name,language,version}`):

  - **`OTEL_RESOURCE_ATTRIBUTES`** (L179-L189) — comma-
    separated `key=value` pairs. `,` and `=` characters in
    keys / values MUST be percent-encoded; we decode via
    `Otel.API.Baggage.Percent.decode/1` (RFC 3986 §2.1). On
    any malformed pair the entire variable value is
    discarded per L191-L193 SHOULD.
  - **`OTEL_SERVICE_NAME`**
    (`configuration/sdk-environment-variables.md` L116) —
    populates `service.name`. Takes precedence over
    `service.name` from `OTEL_RESOURCE_ATTRIBUTES` when
    both are present. When neither is set the spec
    semantic-convention fallback `"unknown_service"` is
    used.

  ## References

  - OTel Resource SDK: `opentelemetry-specification/specification/resource/sdk.md`
  - OTLP proto Resource: `opentelemetry-proto/opentelemetry/proto/resource/v1/resource.proto`
  - OTel SDK env vars: `opentelemetry-specification/specification/configuration/sdk-environment-variables.md` L116
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

  Includes `telemetry.sdk.*` attributes plus environment-derived
  attributes from `OTEL_RESOURCE_ATTRIBUTES` and `OTEL_SERVICE_NAME`
  (see module doc `## Environment-derived defaults`). When
  `service.name` is supplied by neither environment variable, the
  spec semantic-convention fallback `"unknown_service"` is used.
  """
  @spec default() :: t()
  def default do
    base = %{
      "telemetry.sdk.name" => "otel",
      "telemetry.sdk.language" => "elixir",
      "telemetry.sdk.version" => sdk_version()
    }

    env_attrs = parse_resource_attributes(System.get_env("OTEL_RESOURCE_ATTRIBUTES"))

    attributes =
      base
      |> Map.merge(env_attrs)
      |> Map.put("service.name", resolve_service_name(env_attrs))

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

  # `OTEL_SERVICE_NAME` takes precedence over `service.name`
  # in `OTEL_RESOURCE_ATTRIBUTES` per
  # `configuration/sdk-environment-variables.md` L116. Empty
  # string is treated the same as unset — explicit empty
  # service name is not useful and the OTel community
  # convention is to fall back.
  @spec resolve_service_name(env_attrs :: %{String.t() => String.t()}) :: String.t()
  defp resolve_service_name(env_attrs) do
    case System.get_env("OTEL_SERVICE_NAME") do
      env when env in [nil, ""] -> Map.get(env_attrs, "service.name") || "unknown_service"
      env -> env
    end
  end

  # Spec `resource/sdk.md` L184-L189: `key1=value1,key2=value2`
  # with `,` and `=` percent-encoded inside keys/values. Other
  # characters MAY be percent-encoded. We decode via the W3C
  # Baggage percent codec (same RFC 3986 §2.1 contract).
  #
  # Spec L191-L193 SHOULD: on any decoding error, discard the
  # entire variable value. `Enum.reduce_while/3` halts with `%{}`
  # on the first malformed pair, satisfying the whole-or-nothing
  # rule without per-entry partial-acceptance.
  @spec parse_resource_attributes(raw :: String.t() | nil) :: %{String.t() => String.t()}
  defp parse_resource_attributes(raw) when raw in [nil, ""], do: %{}

  defp parse_resource_attributes(raw) do
    raw
    |> String.split(",")
    |> Enum.reduce_while(%{}, fn pair, acc ->
      case String.split(pair, "=", parts: 2) do
        [k, v] ->
          {:cont,
           Map.put(
             acc,
             Otel.API.Baggage.Percent.decode(k),
             Otel.API.Baggage.Percent.decode(v)
           )}

        _ ->
          {:halt, %{}}
      end
    end)
  end
end
