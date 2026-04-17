defmodule Otel.SemConv.Attributes.Code do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Code attributes.
  """

  @doc """
  The column number in `code.file.path` best representing the operation. It **SHOULD** point within the code unit named in `code.function.name`. This attribute **MUST** NOT be used on the Profile signal since the data is already captured in 'message Line'. This constraint is imposed to prevent redundancy and maintain data integrity.

      iex> Otel.SemConv.Attributes.Code.code_column_number()
      :"code.column.number"
  """
  @spec code_column_number :: :"code.column.number"
  def code_column_number do
    :"code.column.number"
  end

  @doc """
  The source code file name that identifies the code unit as uniquely as possible (preferably an absolute file path). This attribute **MUST** NOT be used on the Profile signal since the data is already captured in 'message Function'. This constraint is imposed to prevent redundancy and maintain data integrity.

      iex> Otel.SemConv.Attributes.Code.code_file_path()
      :"code.file.path"
  """
  @spec code_file_path :: :"code.file.path"
  def code_file_path do
    :"code.file.path"
  end

  @doc """
  The method or function fully-qualified name without arguments. The value should fit the natural representation of the language runtime, which is also likely the same used within `code.stacktrace` attribute value. This attribute **MUST** NOT be used on the Profile signal since the data is already captured in 'message Function'. This constraint is imposed to prevent redundancy and maintain data integrity.

      iex> Otel.SemConv.Attributes.Code.code_function_name()
      :"code.function.name"
  """
  @spec code_function_name :: :"code.function.name"
  def code_function_name do
    :"code.function.name"
  end

  @doc """
  The line number in `code.file.path` best representing the operation. It **SHOULD** point within the code unit named in `code.function.name`. This attribute **MUST** NOT be used on the Profile signal since the data is already captured in 'message Line'. This constraint is imposed to prevent redundancy and maintain data integrity.

      iex> Otel.SemConv.Attributes.Code.code_line_number()
      :"code.line.number"
  """
  @spec code_line_number :: :"code.line.number"
  def code_line_number do
    :"code.line.number"
  end

  @doc """
  A stacktrace as a string in the natural representation for the language runtime. The representation is identical to [`exception.stacktrace`](/docs/exceptions/exceptions-spans.md#stacktrace-representation). This attribute **MUST** NOT be used on the Profile signal since the data is already captured in 'message Location'. This constraint is imposed to prevent redundancy and maintain data integrity.

      iex> Otel.SemConv.Attributes.Code.code_stacktrace()
      :"code.stacktrace"
  """
  @spec code_stacktrace :: :"code.stacktrace"
  def code_stacktrace do
    :"code.stacktrace"
  end
end
