defmodule Otel.SemConv.Metrics.Signalr do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Signalr metrics.
  """

  @doc """
  Number of connections that are currently active on the server.

  Instrument: `updowncounter`
  Unit: `{connection}`

      iex> Otel.SemConv.Metrics.Signalr.signalr_server_active_connections()
      "signalr.server.active_connections"
  """
  @spec signalr_server_active_connections :: String.t()
  def signalr_server_active_connections do
    "signalr.server.active_connections"
  end

  @doc """
  The duration of connections on the server.

  Instrument: `histogram`
  Unit: `s`

      iex> Otel.SemConv.Metrics.Signalr.signalr_server_connection_duration()
      "signalr.server.connection.duration"
  """
  @spec signalr_server_connection_duration :: String.t()
  def signalr_server_connection_duration do
    "signalr.server.connection.duration"
  end
end
