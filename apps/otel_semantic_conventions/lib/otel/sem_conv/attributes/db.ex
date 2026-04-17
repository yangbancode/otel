defmodule Otel.SemConv.Attributes.DB do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for DB attributes.
  """

  @doc """
  The name of a collection (table, container) within the database.

      iex> Otel.SemConv.Attributes.DB.db_collection_name()
      "db.collection.name"
  """
  @spec db_collection_name :: String.t()
  def db_collection_name do
    "db.collection.name"
  end

  @doc """
  The name of the database, fully qualified within the server address and port.

      iex> Otel.SemConv.Attributes.DB.db_namespace()
      "db.namespace"
  """
  @spec db_namespace :: String.t()
  def db_namespace do
    "db.namespace"
  end

  @doc """
  The number of queries included in a batch operation.

      iex> Otel.SemConv.Attributes.DB.db_operation_batch_size()
      "db.operation.batch.size"
  """
  @spec db_operation_batch_size :: String.t()
  def db_operation_batch_size do
    "db.operation.batch.size"
  end

  @doc """
  The name of the operation or command being executed.

      iex> Otel.SemConv.Attributes.DB.db_operation_name()
      "db.operation.name"
  """
  @spec db_operation_name :: String.t()
  def db_operation_name do
    "db.operation.name"
  end

  @doc """
  Low cardinality summary of a database query.

      iex> Otel.SemConv.Attributes.DB.db_query_summary()
      "db.query.summary"
  """
  @spec db_query_summary :: String.t()
  def db_query_summary do
    "db.query.summary"
  end

  @doc """
  The database query being executed.

      iex> Otel.SemConv.Attributes.DB.db_query_text()
      "db.query.text"
  """
  @spec db_query_text :: String.t()
  def db_query_text do
    "db.query.text"
  end

  @doc """
  Database response status code.

      iex> Otel.SemConv.Attributes.DB.db_response_status_code()
      "db.response.status_code"
  """
  @spec db_response_status_code :: String.t()
  def db_response_status_code do
    "db.response.status_code"
  end

  @doc """
  The name of a stored procedure within the database.

      iex> Otel.SemConv.Attributes.DB.db_stored_procedure_name()
      "db.stored_procedure.name"
  """
  @spec db_stored_procedure_name :: String.t()
  def db_stored_procedure_name do
    "db.stored_procedure.name"
  end

  @typedoc """
  The database management system (DBMS) product as identified by the client instrumentation.
  """
  @type db_system_name_values :: %{optional(String.t()) => String.t()}

  @doc """
  The database management system (DBMS) product as identified by the client instrumentation.

      iex> Otel.SemConv.Attributes.DB.db_system_name()
      "db.system.name"
  """
  @spec db_system_name :: String.t()
  def db_system_name do
    "db.system.name"
  end

  @doc """
  Enum values for `db_system_name`.

      iex> Otel.SemConv.Attributes.DB.db_system_name_values()["mariadb"]
      "mariadb"
  """
  @spec db_system_name_values :: db_system_name_values()
  def db_system_name_values do
    %{
      "mariadb" => "mariadb",
      "microsoft.sql_server" => "microsoft.sql_server",
      "mysql" => "mysql",
      "postgresql" => "postgresql"
    }
  end
end
