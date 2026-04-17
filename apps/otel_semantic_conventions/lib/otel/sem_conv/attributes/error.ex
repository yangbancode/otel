defmodule Otel.SemConv.Attributes.Error do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Error attributes.
  """

  @typedoc """
  Describes a class of error the operation ended with.
  """
  @type error_type_values :: %{
          :other => :_OTHER
        }

  @doc """
  Describes a class of error the operation ended with.

      iex> Otel.SemConv.Attributes.Error.error_type()
      :"error.type"
  """
  @spec error_type :: :"error.type"
  def error_type do
    :"error.type"
  end

  @doc """
  Enum values for `error_type`.

      iex> Otel.SemConv.Attributes.Error.error_type_values().other
      :_OTHER
  """
  @spec error_type_values :: error_type_values()
  def error_type_values do
    %{
      :other => :_OTHER
    }
  end
end
