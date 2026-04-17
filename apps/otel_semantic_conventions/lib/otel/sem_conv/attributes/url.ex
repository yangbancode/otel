defmodule Otel.SemConv.Attributes.URL do
  # This is an auto-generated file
  @moduledoc """
  OpenTelemetry Semantic Conventions for URL attributes.
  """

  @doc """
  The [URI fragment](https://www.rfc-editor.org/rfc/rfc3986#section-3.5) component

      iex> Otel.SemConv.Attributes.URL.url_fragment()
      :"url.fragment"
  """
  @spec url_fragment :: :"url.fragment"
  def url_fragment do
    :"url.fragment"
  end

  @doc """
  Absolute URL describing a network resource according to [RFC3986](https://www.rfc-editor.org/rfc/rfc3986)

      iex> Otel.SemConv.Attributes.URL.url_full()
      :"url.full"
  """
  @spec url_full :: :"url.full"
  def url_full do
    :"url.full"
  end

  @doc """
  The [URI path](https://www.rfc-editor.org/rfc/rfc3986#section-3.3) component

      iex> Otel.SemConv.Attributes.URL.url_path()
      :"url.path"
  """
  @spec url_path :: :"url.path"
  def url_path do
    :"url.path"
  end

  @doc """
  The [URI query](https://www.rfc-editor.org/rfc/rfc3986#section-3.4) component

      iex> Otel.SemConv.Attributes.URL.url_query()
      :"url.query"
  """
  @spec url_query :: :"url.query"
  def url_query do
    :"url.query"
  end

  @doc """
  The [URI scheme](https://www.rfc-editor.org/rfc/rfc3986#section-3.1) component identifying the used protocol.

      iex> Otel.SemConv.Attributes.URL.url_scheme()
      :"url.scheme"
  """
  @spec url_scheme :: :"url.scheme"
  def url_scheme do
    :"url.scheme"
  end
end
