defmodule Otel.SemConv.Attributes.Exception do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Exception attributes.
  """

  @doc """
  The exception message.

      iex> Otel.SemConv.Attributes.Exception.exception_message()
      :"exception.message"
  """
  @spec exception_message :: :"exception.message"
  def exception_message do
    :"exception.message"
  end

  @doc """
  A stacktrace as a string in the natural representation for the language runtime. The representation is to be determined and documented by each language SIG.

      iex> Otel.SemConv.Attributes.Exception.exception_stacktrace()
      :"exception.stacktrace"
  """
  @spec exception_stacktrace :: :"exception.stacktrace"
  def exception_stacktrace do
    :"exception.stacktrace"
  end

  @doc """
  The type of the exception (its fully-qualified class name, if applicable). The dynamic type of the exception should be preferred over the static type in languages that support it.

      iex> Otel.SemConv.Attributes.Exception.exception_type()
      :"exception.type"
  """
  @spec exception_type :: :"exception.type"
  def exception_type do
    :"exception.type"
  end

  @doc """
  Indicates that the exception is escaping the scope of the span.

      iex> Otel.SemConv.Attributes.Exception.exception_escaped()
      :"exception.escaped"
  """
  @spec exception_escaped :: :"exception.escaped"
  def exception_escaped do
    :"exception.escaped"
  end
end
