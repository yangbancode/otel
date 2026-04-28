defmodule Otel.SemanticConventions.Attributes.Error do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Error attributes.
  """

  @typedoc """
  Describes a class of error the operation ended with.
  """
  @type error_type_values :: %{
          :other => String.t()
        }

  @doc """
  Describes a class of error the operation ended with.

      iex> Otel.SemanticConventions.Attributes.Error.error_type()
      "error.type"
  """
  @spec error_type :: String.t()
  def error_type do
    "error.type"
  end

  @doc """
  Enum values for `error_type`.

      iex> Otel.SemanticConventions.Attributes.Error.error_type_values()[:other]
      "_OTHER"
  """
  @spec error_type_values :: error_type_values()
  def error_type_values do
    %{
      :other => "_OTHER"
    }
  end
end
