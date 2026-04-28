defmodule Otel.SemanticConventions.Metrics.AspNetCore do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for AspNetCore metrics.
  """

  @doc """
  Number of exceptions caught by exception handling middleware.

  Instrument: `counter`
  Unit: `{exception}`

      iex> Otel.SemanticConventions.Metrics.AspNetCore.aspnetcore_diagnostics_exceptions()
      "aspnetcore.diagnostics.exceptions"
  """
  @spec aspnetcore_diagnostics_exceptions :: String.t()
  def aspnetcore_diagnostics_exceptions do
    "aspnetcore.diagnostics.exceptions"
  end

  @doc """
  Number of requests that are currently active on the server that hold a rate limiting lease.

  Instrument: `updowncounter`
  Unit: `{request}`

      iex> Otel.SemanticConventions.Metrics.AspNetCore.aspnetcore_rate_limiting_active_request_leases()
      "aspnetcore.rate_limiting.active_request_leases"
  """
  @spec aspnetcore_rate_limiting_active_request_leases :: String.t()
  def aspnetcore_rate_limiting_active_request_leases do
    "aspnetcore.rate_limiting.active_request_leases"
  end

  @doc """
  Number of requests that are currently queued, waiting to acquire a rate limiting lease.

  Instrument: `updowncounter`
  Unit: `{request}`

      iex> Otel.SemanticConventions.Metrics.AspNetCore.aspnetcore_rate_limiting_queued_requests()
      "aspnetcore.rate_limiting.queued_requests"
  """
  @spec aspnetcore_rate_limiting_queued_requests :: String.t()
  def aspnetcore_rate_limiting_queued_requests do
    "aspnetcore.rate_limiting.queued_requests"
  end

  @doc """
  The time the request spent in a queue waiting to acquire a rate limiting lease.

  Instrument: `histogram`
  Unit: `s`

      iex> Otel.SemanticConventions.Metrics.AspNetCore.aspnetcore_rate_limiting_request_time_in_queue()
      "aspnetcore.rate_limiting.request.time_in_queue"
  """
  @spec aspnetcore_rate_limiting_request_time_in_queue :: String.t()
  def aspnetcore_rate_limiting_request_time_in_queue do
    "aspnetcore.rate_limiting.request.time_in_queue"
  end

  @doc """
  The duration of rate limiting lease held by requests on the server.

  Instrument: `histogram`
  Unit: `s`

      iex> Otel.SemanticConventions.Metrics.AspNetCore.aspnetcore_rate_limiting_request_lease_duration()
      "aspnetcore.rate_limiting.request_lease.duration"
  """
  @spec aspnetcore_rate_limiting_request_lease_duration :: String.t()
  def aspnetcore_rate_limiting_request_lease_duration do
    "aspnetcore.rate_limiting.request_lease.duration"
  end

  @doc """
  Number of requests that tried to acquire a rate limiting lease.

  Instrument: `counter`
  Unit: `{request}`

      iex> Otel.SemanticConventions.Metrics.AspNetCore.aspnetcore_rate_limiting_requests()
      "aspnetcore.rate_limiting.requests"
  """
  @spec aspnetcore_rate_limiting_requests :: String.t()
  def aspnetcore_rate_limiting_requests do
    "aspnetcore.rate_limiting.requests"
  end

  @doc """
  Number of requests that were attempted to be matched to an endpoint.

  Instrument: `counter`
  Unit: `{match_attempt}`

      iex> Otel.SemanticConventions.Metrics.AspNetCore.aspnetcore_routing_match_attempts()
      "aspnetcore.routing.match_attempts"
  """
  @spec aspnetcore_routing_match_attempts :: String.t()
  def aspnetcore_routing_match_attempts do
    "aspnetcore.routing.match_attempts"
  end
end
