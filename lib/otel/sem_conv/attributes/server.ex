defmodule Otel.SemConv.Attributes.Server do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Server attributes.
  """

  @doc """
  Server domain name if available without reverse DNS lookup; otherwise, IP address or Unix domain socket name.

      iex> Otel.SemConv.Attributes.Server.server_address()
      "server.address"
  """
  @spec server_address :: String.t()
  def server_address do
    "server.address"
  end

  @doc """
  Server port number.

      iex> Otel.SemConv.Attributes.Server.server_port()
      "server.port"
  """
  @spec server_port :: String.t()
  def server_port do
    "server.port"
  end
end
