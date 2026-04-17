defmodule Otel.SemConv.Attributes.Telemetry do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Telemetry attributes.
  """

  @typedoc """
  The language of the telemetry SDK.
  """
  @type telemetry_sdk_language_values :: %{optional(String.t()) => String.t()}

  @doc """
  The language of the telemetry SDK.

      iex> Otel.SemConv.Attributes.Telemetry.telemetry_sdk_language()
      "telemetry.sdk.language"
  """
  @spec telemetry_sdk_language :: String.t()
  def telemetry_sdk_language do
    "telemetry.sdk.language"
  end

  @doc """
  Enum values for `telemetry_sdk_language`.

      iex> Otel.SemConv.Attributes.Telemetry.telemetry_sdk_language_values()["cpp"]
      "cpp"
  """
  @spec telemetry_sdk_language_values :: telemetry_sdk_language_values()
  def telemetry_sdk_language_values do
    %{
      "cpp" => "cpp",
      "dotnet" => "dotnet",
      "erlang" => "erlang",
      "go" => "go",
      "java" => "java",
      "nodejs" => "nodejs",
      "php" => "php",
      "python" => "python",
      "ruby" => "ruby",
      "rust" => "rust",
      "swift" => "swift",
      "webjs" => "webjs"
    }
  end

  @doc """
  The name of the telemetry SDK as defined above.

      iex> Otel.SemConv.Attributes.Telemetry.telemetry_sdk_name()
      "telemetry.sdk.name"
  """
  @spec telemetry_sdk_name :: String.t()
  def telemetry_sdk_name do
    "telemetry.sdk.name"
  end

  @doc """
  The version string of the telemetry SDK.

      iex> Otel.SemConv.Attributes.Telemetry.telemetry_sdk_version()
      "telemetry.sdk.version"
  """
  @spec telemetry_sdk_version :: String.t()
  def telemetry_sdk_version do
    "telemetry.sdk.version"
  end
end
