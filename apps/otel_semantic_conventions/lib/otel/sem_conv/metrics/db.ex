defmodule Otel.SemConv.Metrics.DB do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for DB metrics.
  """

  @doc """
  Duration of database client operations.

  Instrument: `histogram`
  Unit: `s`

      iex> Otel.SemConv.Metrics.DB.db_client_operation_duration()
      "db.client.operation.duration"
  """
  @spec db_client_operation_duration :: String.t()
  def db_client_operation_duration do
    "db.client.operation.duration"
  end
end
