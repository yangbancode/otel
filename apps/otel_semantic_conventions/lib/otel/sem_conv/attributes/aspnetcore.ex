defmodule Otel.SemConv.Attributes.Aspnetcore do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for Aspnetcore attributes.
  """

  @typedoc """
  ASP.NET Core exception middleware handling result.
  """
  @type aspnetcore_diagnostics_exception_result_values :: %{optional(String.t()) => String.t()}

  @doc """
  ASP.NET Core exception middleware handling result.

      iex> Otel.SemConv.Attributes.Aspnetcore.aspnetcore_diagnostics_exception_result()
      "aspnetcore.diagnostics.exception.result"
  """
  @spec aspnetcore_diagnostics_exception_result :: String.t()
  def aspnetcore_diagnostics_exception_result do
    "aspnetcore.diagnostics.exception.result"
  end

  @doc """
  Enum values for `aspnetcore_diagnostics_exception_result`.

      iex> Otel.SemConv.Attributes.Aspnetcore.aspnetcore_diagnostics_exception_result_values()["handled"]
      "handled"
  """
  @spec aspnetcore_diagnostics_exception_result_values ::
          aspnetcore_diagnostics_exception_result_values()
  def aspnetcore_diagnostics_exception_result_values do
    %{
      "handled" => "handled",
      "unhandled" => "unhandled",
      "skipped" => "skipped",
      "aborted" => "aborted"
    }
  end

  @doc """
  Full type name of the [`IExceptionHandler`](https://learn.microsoft.com/dotnet/api/microsoft.aspnetcore.diagnostics.iexceptionhandler) implementation that handled the exception.

      iex> Otel.SemConv.Attributes.Aspnetcore.aspnetcore_diagnostics_handler_type()
      "aspnetcore.diagnostics.handler.type"
  """
  @spec aspnetcore_diagnostics_handler_type :: String.t()
  def aspnetcore_diagnostics_handler_type do
    "aspnetcore.diagnostics.handler.type"
  end

  @doc """
  Rate limiting policy name.

      iex> Otel.SemConv.Attributes.Aspnetcore.aspnetcore_rate_limiting_policy()
      "aspnetcore.rate_limiting.policy"
  """
  @spec aspnetcore_rate_limiting_policy :: String.t()
  def aspnetcore_rate_limiting_policy do
    "aspnetcore.rate_limiting.policy"
  end

  @typedoc """
  Rate-limiting result, shows whether the lease was acquired or contains a rejection reason
  """
  @type aspnetcore_rate_limiting_result_values :: %{optional(String.t()) => String.t()}

  @doc """
  Rate-limiting result, shows whether the lease was acquired or contains a rejection reason

      iex> Otel.SemConv.Attributes.Aspnetcore.aspnetcore_rate_limiting_result()
      "aspnetcore.rate_limiting.result"
  """
  @spec aspnetcore_rate_limiting_result :: String.t()
  def aspnetcore_rate_limiting_result do
    "aspnetcore.rate_limiting.result"
  end

  @doc """
  Enum values for `aspnetcore_rate_limiting_result`.

      iex> Otel.SemConv.Attributes.Aspnetcore.aspnetcore_rate_limiting_result_values()["acquired"]
      "acquired"
  """
  @spec aspnetcore_rate_limiting_result_values :: aspnetcore_rate_limiting_result_values()
  def aspnetcore_rate_limiting_result_values do
    %{
      "acquired" => "acquired",
      "endpoint_limiter" => "endpoint_limiter",
      "global_limiter" => "global_limiter",
      "request_canceled" => "request_canceled"
    }
  end

  @doc """
  Flag indicating if request was handled by the application pipeline.

      iex> Otel.SemConv.Attributes.Aspnetcore.aspnetcore_request_is_unhandled()
      "aspnetcore.request.is_unhandled"
  """
  @spec aspnetcore_request_is_unhandled :: String.t()
  def aspnetcore_request_is_unhandled do
    "aspnetcore.request.is_unhandled"
  end

  @doc """
  A value that indicates whether the matched route is a fallback route.

      iex> Otel.SemConv.Attributes.Aspnetcore.aspnetcore_routing_is_fallback()
      "aspnetcore.routing.is_fallback"
  """
  @spec aspnetcore_routing_is_fallback :: String.t()
  def aspnetcore_routing_is_fallback do
    "aspnetcore.routing.is_fallback"
  end

  @typedoc """
  Match result - success or failure
  """
  @type aspnetcore_routing_match_status_values :: %{optional(String.t()) => String.t()}

  @doc """
  Match result - success or failure

      iex> Otel.SemConv.Attributes.Aspnetcore.aspnetcore_routing_match_status()
      "aspnetcore.routing.match_status"
  """
  @spec aspnetcore_routing_match_status :: String.t()
  def aspnetcore_routing_match_status do
    "aspnetcore.routing.match_status"
  end

  @doc """
  Enum values for `aspnetcore_routing_match_status`.

      iex> Otel.SemConv.Attributes.Aspnetcore.aspnetcore_routing_match_status_values()["success"]
      "success"
  """
  @spec aspnetcore_routing_match_status_values :: aspnetcore_routing_match_status_values()
  def aspnetcore_routing_match_status_values do
    %{
      "success" => "success",
      "failure" => "failure"
    }
  end

  @doc """
  A value that indicates whether the user is authenticated.

      iex> Otel.SemConv.Attributes.Aspnetcore.aspnetcore_user_is_authenticated()
      "aspnetcore.user.is_authenticated"
  """
  @spec aspnetcore_user_is_authenticated :: String.t()
  def aspnetcore_user_is_authenticated do
    "aspnetcore.user.is_authenticated"
  end
end
