defmodule Otel.SemConv.Attributes.Signalr do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Signalr attributes.
  """

  @typedoc """
  SignalR HTTP connection closure status.
  """
  @type signalr_connection_status_values :: %{optional(String.t()) => String.t()}

  @doc """
  SignalR HTTP connection closure status.

      iex> Otel.SemConv.Attributes.Signalr.signalr_connection_status()
      "signalr.connection.status"
  """
  @spec signalr_connection_status :: String.t()
  def signalr_connection_status do
    "signalr.connection.status"
  end

  @doc """
  Enum values for `signalr_connection_status`.

      iex> Otel.SemConv.Attributes.Signalr.signalr_connection_status_values()["normal_closure"]
      "normal_closure"
  """
  @spec signalr_connection_status_values :: signalr_connection_status_values()
  def signalr_connection_status_values do
    %{
      "normal_closure" => "normal_closure",
      "timeout" => "timeout",
      "app_shutdown" => "app_shutdown"
    }
  end

  @typedoc """
  [SignalR transport type](https://github.com/dotnet/aspnetcore/blob/main/src/SignalR/docs/specs/TransportProtocols.md)
  """
  @type signalr_transport_values :: %{optional(String.t()) => String.t()}

  @doc """
  [SignalR transport type](https://github.com/dotnet/aspnetcore/blob/main/src/SignalR/docs/specs/TransportProtocols.md)

      iex> Otel.SemConv.Attributes.Signalr.signalr_transport()
      "signalr.transport"
  """
  @spec signalr_transport :: String.t()
  def signalr_transport do
    "signalr.transport"
  end

  @doc """
  Enum values for `signalr_transport`.

      iex> Otel.SemConv.Attributes.Signalr.signalr_transport_values()["server_sent_events"]
      "server_sent_events"
  """
  @spec signalr_transport_values :: signalr_transport_values()
  def signalr_transport_values do
    %{
      "server_sent_events" => "server_sent_events",
      "long_polling" => "long_polling",
      "web_sockets" => "web_sockets"
    }
  end
end
