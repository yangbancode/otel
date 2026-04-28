defmodule Otel.SemanticConventions.Metrics.Kestrel do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Kestrel metrics.
  """

  @doc """
  Number of connections that are currently active on the server.

  Instrument: `updowncounter`
  Unit: `{connection}`

      iex> Otel.SemanticConventions.Metrics.Kestrel.kestrel_active_connections()
      "kestrel.active_connections"
  """
  @spec kestrel_active_connections :: String.t()
  def kestrel_active_connections do
    "kestrel.active_connections"
  end

  @doc """
  Number of TLS handshakes that are currently in progress on the server.

  Instrument: `updowncounter`
  Unit: `{handshake}`

      iex> Otel.SemanticConventions.Metrics.Kestrel.kestrel_active_tls_handshakes()
      "kestrel.active_tls_handshakes"
  """
  @spec kestrel_active_tls_handshakes :: String.t()
  def kestrel_active_tls_handshakes do
    "kestrel.active_tls_handshakes"
  end

  @doc """
  The duration of connections on the server.

  Instrument: `histogram`
  Unit: `s`

      iex> Otel.SemanticConventions.Metrics.Kestrel.kestrel_connection_duration()
      "kestrel.connection.duration"
  """
  @spec kestrel_connection_duration :: String.t()
  def kestrel_connection_duration do
    "kestrel.connection.duration"
  end

  @doc """
  Number of connections that are currently queued and are waiting to start.

  Instrument: `updowncounter`
  Unit: `{connection}`

      iex> Otel.SemanticConventions.Metrics.Kestrel.kestrel_queued_connections()
      "kestrel.queued_connections"
  """
  @spec kestrel_queued_connections :: String.t()
  def kestrel_queued_connections do
    "kestrel.queued_connections"
  end

  @doc """
  Number of HTTP requests on multiplexed connections (HTTP/2 and HTTP/3) that are currently queued and are waiting to start.

  Instrument: `updowncounter`
  Unit: `{request}`

      iex> Otel.SemanticConventions.Metrics.Kestrel.kestrel_queued_requests()
      "kestrel.queued_requests"
  """
  @spec kestrel_queued_requests :: String.t()
  def kestrel_queued_requests do
    "kestrel.queued_requests"
  end

  @doc """
  Number of connections rejected by the server.

  Instrument: `counter`
  Unit: `{connection}`

      iex> Otel.SemanticConventions.Metrics.Kestrel.kestrel_rejected_connections()
      "kestrel.rejected_connections"
  """
  @spec kestrel_rejected_connections :: String.t()
  def kestrel_rejected_connections do
    "kestrel.rejected_connections"
  end

  @doc """
  The duration of TLS handshakes on the server.

  Instrument: `histogram`
  Unit: `s`

      iex> Otel.SemanticConventions.Metrics.Kestrel.kestrel_tls_handshake_duration()
      "kestrel.tls_handshake.duration"
  """
  @spec kestrel_tls_handshake_duration :: String.t()
  def kestrel_tls_handshake_duration do
    "kestrel.tls_handshake.duration"
  end

  @doc """
  Number of connections that are currently upgraded (WebSockets). .

  Instrument: `updowncounter`
  Unit: `{connection}`

      iex> Otel.SemanticConventions.Metrics.Kestrel.kestrel_upgraded_connections()
      "kestrel.upgraded_connections"
  """
  @spec kestrel_upgraded_connections :: String.t()
  def kestrel_upgraded_connections do
    "kestrel.upgraded_connections"
  end
end
