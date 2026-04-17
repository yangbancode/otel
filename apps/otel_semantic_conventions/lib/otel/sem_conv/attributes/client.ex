defmodule Otel.SemConv.Attributes.Client do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Client attributes.
  """

  @doc """
  Client address - domain name if available without reverse DNS lookup; otherwise, IP address or Unix domain socket name.

      iex> Otel.SemConv.Attributes.Client.client_address()
      :"client.address"
  """
  @spec client_address :: :"client.address"
  def client_address do
    :"client.address"
  end

  @doc """
  Client port number.

      iex> Otel.SemConv.Attributes.Client.client_port()
      :"client.port"
  """
  @spec client_port :: :"client.port"
  def client_port do
    :"client.port"
  end
end
