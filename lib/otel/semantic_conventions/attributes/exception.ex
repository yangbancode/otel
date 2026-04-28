defmodule Otel.SemanticConventions.Attributes.Exception do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Exception attributes.
  """

  @doc """
  The exception message.

      iex> Otel.SemanticConventions.Attributes.Exception.exception_message()
      "exception.message"
  """
  @spec exception_message :: String.t()
  def exception_message do
    "exception.message"
  end

  @doc """
  A stacktrace as a string in the natural representation for the language runtime. The representation is to be determined and documented by each language SIG.

      iex> Otel.SemanticConventions.Attributes.Exception.exception_stacktrace()
      "exception.stacktrace"
  """
  @spec exception_stacktrace :: String.t()
  def exception_stacktrace do
    "exception.stacktrace"
  end

  @doc """
  The type of the exception (its fully-qualified class name, if applicable). The dynamic type of the exception should be preferred over the static type in languages that support it.

      iex> Otel.SemanticConventions.Attributes.Exception.exception_type()
      "exception.type"
  """
  @spec exception_type :: String.t()
  def exception_type do
    "exception.type"
  end

  @doc """
  Indicates that the exception is escaping the scope of the span.

      iex> Otel.SemanticConventions.Attributes.Exception.exception_escaped()
      "exception.escaped"
  """
  @spec exception_escaped :: String.t()
  def exception_escaped do
    "exception.escaped"
  end
end
