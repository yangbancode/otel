defmodule Otel.SemConv.Attributes.HTTP do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for HTTP attributes.
  """

  @doc """
  HTTP request headers, `<key>` being the normalized HTTP Header name (lowercase), the value being the header values.

      iex> Otel.SemConv.Attributes.HTTP.http_request_header()
      :"http.request.header"
  """
  @spec http_request_header :: :"http.request.header"
  def http_request_header do
    :"http.request.header"
  end

  @typedoc """
  HTTP request method.
  """
  @type http_request_method_values :: %{
          :connect => :CONNECT,
          :delete => :DELETE,
          :get => :GET,
          :head => :HEAD,
          :options => :OPTIONS,
          :patch => :PATCH,
          :post => :POST,
          :put => :PUT,
          :trace => :TRACE,
          :other => :_OTHER
        }

  @doc """
  HTTP request method.

      iex> Otel.SemConv.Attributes.HTTP.http_request_method()
      :"http.request.method"
  """
  @spec http_request_method :: :"http.request.method"
  def http_request_method do
    :"http.request.method"
  end

  @doc """
  Enum values for `http_request_method`.

      iex> Otel.SemConv.Attributes.HTTP.http_request_method_values().connect
      :CONNECT
  """
  @spec http_request_method_values :: http_request_method_values()
  def http_request_method_values do
    %{
      :connect => :CONNECT,
      :delete => :DELETE,
      :get => :GET,
      :head => :HEAD,
      :options => :OPTIONS,
      :patch => :PATCH,
      :post => :POST,
      :put => :PUT,
      :trace => :TRACE,
      :other => :_OTHER
    }
  end

  @doc """
  Original HTTP method sent by the client in the request line.

      iex> Otel.SemConv.Attributes.HTTP.http_request_method_original()
      :"http.request.method_original"
  """
  @spec http_request_method_original :: :"http.request.method_original"
  def http_request_method_original do
    :"http.request.method_original"
  end

  @doc """
  The ordinal number of request resending attempt (for any reason, including redirects).

      iex> Otel.SemConv.Attributes.HTTP.http_request_resend_count()
      :"http.request.resend_count"
  """
  @spec http_request_resend_count :: :"http.request.resend_count"
  def http_request_resend_count do
    :"http.request.resend_count"
  end

  @doc """
  HTTP response headers, `<key>` being the normalized HTTP Header name (lowercase), the value being the header values.

      iex> Otel.SemConv.Attributes.HTTP.http_response_header()
      :"http.response.header"
  """
  @spec http_response_header :: :"http.response.header"
  def http_response_header do
    :"http.response.header"
  end

  @doc """
  [HTTP response status code](https://tools.ietf.org/html/rfc7231#section-6).

      iex> Otel.SemConv.Attributes.HTTP.http_response_status_code()
      :"http.response.status_code"
  """
  @spec http_response_status_code :: :"http.response.status_code"
  def http_response_status_code do
    :"http.response.status_code"
  end

  @doc """
  The matched route template for the request. This **MUST** be low-cardinality and include all static path segments, with dynamic path segments represented with placeholders.

      iex> Otel.SemConv.Attributes.HTTP.http_route()
      :"http.route"
  """
  @spec http_route :: :"http.route"
  def http_route do
    :"http.route"
  end
end
