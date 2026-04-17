defmodule Otel.SemConv.Attributes.Otel do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Otel attributes.
  """

  @typedoc """
  Name of the code, either "OK" or "ERROR". **MUST** NOT be set if the status code is UNSET.
  """
  @type otel_status_code_values :: %{
          :ok => :OK,
          :error => :ERROR
        }

  @doc """
  Name of the code, either "OK" or "ERROR". **MUST** NOT be set if the status code is UNSET.

      iex> Otel.SemConv.Attributes.Otel.otel_status_code()
      :"otel.status_code"
  """
  @spec otel_status_code :: :"otel.status_code"
  def otel_status_code do
    :"otel.status_code"
  end

  @doc """
  Enum values for `otel_status_code`.

      iex> Otel.SemConv.Attributes.Otel.otel_status_code_values().ok
      :OK
  """
  @spec otel_status_code_values :: otel_status_code_values()
  def otel_status_code_values do
    %{
      :ok => :OK,
      :error => :ERROR
    }
  end

  @doc """
  Description of the Status if it has a value, otherwise not set.

      iex> Otel.SemConv.Attributes.Otel.otel_status_description()
      :"otel.status_description"
  """
  @spec otel_status_description :: :"otel.status_description"
  def otel_status_description do
    :"otel.status_description"
  end

  @doc """
  The name of the instrumentation scope - (`InstrumentationScope.Name` in OTLP).

      iex> Otel.SemConv.Attributes.Otel.otel_scope_name()
      :"otel.scope.name"
  """
  @spec otel_scope_name :: :"otel.scope.name"
  def otel_scope_name do
    :"otel.scope.name"
  end

  @doc """
  The version of the instrumentation scope - (`InstrumentationScope.Version` in OTLP).

      iex> Otel.SemConv.Attributes.Otel.otel_scope_version()
      :"otel.scope.version"
  """
  @spec otel_scope_version :: :"otel.scope.version"
  def otel_scope_version do
    :"otel.scope.version"
  end
end
