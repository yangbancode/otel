defmodule Otel.Exporter.OTLP.Traces do
  @moduledoc """
  OTLP HTTP Exporter for traces.

  Exports spans as binary protobuf over HTTP POST to an OTLP endpoint.
  Implements the SpanExporter behaviour.

  Default endpoint: http://localhost:4318/v1/traces

  ## SSL/TLS

  For HTTPS endpoints, SSL certificate verification is enabled by default
  using system CA certificates (`:public_key.cacerts_get/0`).

  Custom SSL options can be provided via the `:ssl_options` config key:

      %{endpoint: "https://collector:4318", ssl_options: [cacertfile: "/path/to/ca.pem"]}
  """

  @behaviour Otel.SDK.Trace.SpanExporter

  @default_endpoint "http://localhost:4318"
  @traces_path "/v1/traces"
  @default_timeout 10_000
  @user_agent "OTel-OTLP-Exporter-Elixir/0.1.0"

  @spec init(config :: term()) :: {:ok, Otel.SDK.Trace.SpanExporter.state()} | :ignore
  @impl true
  def init(config) do
    :inets.start()

    endpoint = build_endpoint(config)
    headers = build_headers(config)
    compression = Map.get(config, :compression, :none)
    timeout = Map.get(config, :timeout, @default_timeout)
    ssl_options = build_ssl_options(endpoint, config)

    {:ok,
     %{
       endpoint: endpoint,
       headers: headers,
       compression: compression,
       timeout: timeout,
       ssl_options: ssl_options
     }}
  end

  @spec export(
          spans :: [Otel.SDK.Trace.Span.t()],
          resource :: Otel.SDK.Resource.t(),
          state :: Otel.SDK.Trace.SpanExporter.state()
        ) :: :ok | :error
  @impl true
  def export([], _resource, _state), do: :ok

  def export(spans, resource, state) do
    body = Otel.Exporter.OTLP.Encoder.encode_traces(spans, resource)
    body = maybe_compress(body, state.compression)

    headers = request_headers(state.headers, state.compression)
    url = String.to_charlist(state.endpoint)
    http_options = build_http_options(state)

    case :httpc.request(:post, {url, headers, ~c"application/x-protobuf", body}, http_options, []) do
      {:ok, {{_version, status, _reason}, _headers, _body}} when status in 200..299 ->
        :ok

      _ ->
        :error
    end
  end

  @spec shutdown(state :: Otel.SDK.Trace.SpanExporter.state()) :: :ok
  @impl true
  def shutdown(_state), do: :ok

  # --- Private ---

  @spec build_endpoint(config :: map()) :: String.t()
  defp build_endpoint(config) do
    endpoint = Map.get(config, :endpoint, @default_endpoint)
    String.trim_trailing(endpoint, "/") <> @traces_path
  end

  @spec build_headers(config :: map()) :: [{charlist(), charlist()}]
  defp build_headers(config) do
    user_headers =
      config
      |> Map.get(:headers, %{})
      |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

    [{~c"user-agent", String.to_charlist(@user_agent)} | user_headers]
  end

  @spec build_ssl_options(endpoint :: String.t(), config :: map()) :: keyword()
  defp build_ssl_options(endpoint, config) do
    case Map.get(config, :ssl_options) do
      opts when is_list(opts) ->
        opts

      _ ->
        if String.starts_with?(endpoint, "https") do
          default_ssl_options(endpoint)
        else
          []
        end
    end
  end

  @spec default_ssl_options(endpoint :: String.t()) :: keyword()
  defp default_ssl_options(endpoint) do
    host = endpoint |> URI.parse() |> Map.get(:host, "localhost")

    [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(host),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]
  end

  @spec build_http_options(state :: map()) :: keyword()
  defp build_http_options(state) do
    opts = [{:timeout, state.timeout}]

    if state.ssl_options != [] do
      [{:ssl, state.ssl_options} | opts]
    else
      opts
    end
  end

  @spec request_headers(
          base_headers :: [{charlist(), charlist()}],
          compression :: :gzip | :none
        ) :: [{charlist(), charlist()}]
  defp request_headers(headers, :gzip) do
    [{~c"content-encoding", ~c"gzip"} | headers]
  end

  defp request_headers(headers, _), do: headers

  @spec maybe_compress(body :: binary(), compression :: :gzip | :none) :: binary()
  defp maybe_compress(body, :gzip), do: :zlib.gzip(body)
  defp maybe_compress(body, _), do: body
end
