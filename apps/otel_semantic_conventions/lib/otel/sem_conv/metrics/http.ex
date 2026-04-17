defmodule Otel.SemConv.Metrics.HTTP do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for HTTP metrics.
  """

  @doc """
  Duration of HTTP client requests.

  Instrument: `histogram`
  Unit: `s`

      iex> Otel.SemConv.Metrics.HTTP.http_client_request_duration()
      "http.client.request.duration"
  """
  @spec http_client_request_duration :: String.t()
  def http_client_request_duration do
    "http.client.request.duration"
  end

  @doc """
  Duration of HTTP server requests.

  Instrument: `histogram`
  Unit: `s`

      iex> Otel.SemConv.Metrics.HTTP.http_server_request_duration()
      "http.server.request.duration"
  """
  @spec http_server_request_duration :: String.t()
  def http_server_request_duration do
    "http.server.request.duration"
  end
end
