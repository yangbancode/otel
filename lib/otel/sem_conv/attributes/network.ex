defmodule Otel.SemConv.Attributes.Network do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Network attributes.
  """

  @doc """
  Local address of the network connection - IP address or Unix domain socket name.

      iex> Otel.SemConv.Attributes.Network.network_local_address()
      "network.local.address"
  """
  @spec network_local_address :: String.t()
  def network_local_address do
    "network.local.address"
  end

  @doc """
  Local port number of the network connection.

      iex> Otel.SemConv.Attributes.Network.network_local_port()
      "network.local.port"
  """
  @spec network_local_port :: String.t()
  def network_local_port do
    "network.local.port"
  end

  @doc """
  Peer address of the network connection - IP address or Unix domain socket name.

      iex> Otel.SemConv.Attributes.Network.network_peer_address()
      "network.peer.address"
  """
  @spec network_peer_address :: String.t()
  def network_peer_address do
    "network.peer.address"
  end

  @doc """
  Peer port number of the network connection.

      iex> Otel.SemConv.Attributes.Network.network_peer_port()
      "network.peer.port"
  """
  @spec network_peer_port :: String.t()
  def network_peer_port do
    "network.peer.port"
  end

  @doc """
  [OSI application layer](https://wikipedia.org/wiki/Application_layer) or non-OSI equivalent.

      iex> Otel.SemConv.Attributes.Network.network_protocol_name()
      "network.protocol.name"
  """
  @spec network_protocol_name :: String.t()
  def network_protocol_name do
    "network.protocol.name"
  end

  @doc """
  The actual version of the protocol used for network communication.

      iex> Otel.SemConv.Attributes.Network.network_protocol_version()
      "network.protocol.version"
  """
  @spec network_protocol_version :: String.t()
  def network_protocol_version do
    "network.protocol.version"
  end

  @typedoc """
  [OSI transport layer](https://wikipedia.org/wiki/Transport_layer) or [inter-process communication method](https://wikipedia.org/wiki/Inter-process_communication).
  """
  @type network_transport_values :: %{
          :tcp => String.t(),
          :udp => String.t(),
          :pipe => String.t(),
          :unix => String.t(),
          :quic => String.t()
        }

  @doc """
  [OSI transport layer](https://wikipedia.org/wiki/Transport_layer) or [inter-process communication method](https://wikipedia.org/wiki/Inter-process_communication).

      iex> Otel.SemConv.Attributes.Network.network_transport()
      "network.transport"
  """
  @spec network_transport :: String.t()
  def network_transport do
    "network.transport"
  end

  @doc """
  Enum values for `network_transport`.

      iex> Otel.SemConv.Attributes.Network.network_transport_values()[:tcp]
      "tcp"
  """
  @spec network_transport_values :: network_transport_values()
  def network_transport_values do
    %{
      :tcp => "tcp",
      :udp => "udp",
      :pipe => "pipe",
      :unix => "unix",
      :quic => "quic"
    }
  end

  @typedoc """
  [OSI network layer](https://wikipedia.org/wiki/Network_layer) or non-OSI equivalent.
  """
  @type network_type_values :: %{
          :ipv4 => String.t(),
          :ipv6 => String.t()
        }

  @doc """
  [OSI network layer](https://wikipedia.org/wiki/Network_layer) or non-OSI equivalent.

      iex> Otel.SemConv.Attributes.Network.network_type()
      "network.type"
  """
  @spec network_type :: String.t()
  def network_type do
    "network.type"
  end

  @doc """
  Enum values for `network_type`.

      iex> Otel.SemConv.Attributes.Network.network_type_values()[:ipv4]
      "ipv4"
  """
  @spec network_type_values :: network_type_values()
  def network_type_values do
    %{
      :ipv4 => "ipv4",
      :ipv6 => "ipv6"
    }
  end
end
