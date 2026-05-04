defmodule Otel.Metrics.MetricExporter do
  @moduledoc """
  OTLP HTTP Exporter for metrics.

  Exports metrics as binary protobuf over HTTP POST to an OTLP endpoint.
  Implements the MetricExporter behaviour.

  ## Configuration

  Top-level `:otel` keys — the same flat config flows to all
  three OTLP exporters (trace / metrics / logs):

      # config/runtime.exs
      config :otel,
        endpoint:
          System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") || "http://localhost:4318"

  Accepted keys (all optional):

  | Key | Default | Notes |
  |---|---|---|
  | `:endpoint` | `http://localhost:4318` | Base URL; `/v1/metrics` is appended |
  | `:headers` | `%{}` | `%{header_name => value}` map of additional headers |
  | `:compression` | `:none` | `:gzip` or `:none` |
  | `:timeout` | `10_000` | Request timeout in milliseconds |
  | `:ssl` | system CAs for HTTPS | See "SSL/TLS" below |

  ## SSL/TLS

  For HTTPS endpoints, SSL certificate verification is enabled by default
  using system CA certificates (`:public_key.cacerts_get/0`).

  Custom SSL options can be provided via the `:ssl` config key.

  ## Retry

  Transient errors are retried with exponential backoff and
  jitter per `protocol/exporter.md` §Retry L181-L183. Retry
  behavior is delegated to `Otel.OTLP.HTTP.Retry` and uses
  the Java OTLP SDK defaults verbatim (5 attempts, 1s → 5s
  capped, 1.5x multiplier, ±20% jitter). Not user-tunable —
  the spec does not mandate values, and the Java defaults are
  the de-facto OTLP standard.
  """

  @typedoc "Internal exporter state — opaque to callers."
  @type state :: map()

  @default_endpoint "http://localhost:4318"
  @metrics_path "/v1/metrics"
  @default_timeout 10_000

  @spec init(config :: term()) :: {:ok, state()} | :ignore
  def init(config) do
    endpoint = resolve_endpoint(config)
    headers = resolve_headers(config)
    compression = Map.get(config, :compression, :none)
    timeout = Map.get(config, :timeout, @default_timeout)
    ssl = build_ssl(endpoint, config)

    {:ok,
     %{
       endpoint: endpoint,
       headers: headers,
       compression: compression,
       timeout: timeout,
       ssl: ssl
     }}
  end

  @spec export(
          metrics :: [Otel.Metrics.MetricReader.metric()],
          state :: state()
        ) :: :ok | :error
  def export([], _state), do: :ok

  def export(metrics, state) do
    body = Otel.OTLP.Encoder.encode_metrics(metrics)
    body = maybe_compress(body, state.compression)

    headers = request_headers(state.headers, state.compression)
    url = String.to_charlist(state.endpoint)
    http_options = build_http_options(state)

    case Otel.OTLP.HTTP.Retry.request(
           {url, headers, ~c"application/x-protobuf", body},
           http_options,
           []
         ) do
      :ok -> :ok
      {:error, _reason} -> :error
    end
  end

  @spec force_flush(state :: state()) :: :ok
  def force_flush(_state), do: :ok

  @spec shutdown(state :: state()) :: :ok
  def shutdown(_state), do: :ok

  # --- Private ---

  @spec resolve_endpoint(config :: map()) :: String.t()
  defp resolve_endpoint(config) do
    String.trim_trailing(Map.get(config, :endpoint, @default_endpoint), "/") <> @metrics_path
  end

  @spec resolve_headers(config :: map()) :: [{charlist(), charlist()}]
  defp resolve_headers(config) do
    user_headers =
      config
      |> Map.get(:headers, %{})
      |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

    [{~c"user-agent", String.to_charlist(user_agent())} | user_headers]
  end

  @spec user_agent() :: String.t()
  defp user_agent, do: "Otel/#{Application.spec(:otel, :vsn)}"

  @spec build_ssl(endpoint :: String.t(), config :: map()) :: keyword()
  defp build_ssl(endpoint, config) do
    case Map.get(config, :ssl) do
      opts when is_list(opts) ->
        opts

      _ ->
        if String.starts_with?(endpoint, "https") do
          default_ssl(endpoint)
        else
          []
        end
    end
  end

  @spec default_ssl(endpoint :: String.t()) :: keyword()
  defp default_ssl(endpoint) do
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

    if state.ssl != [] do
      [{:ssl, state.ssl} | opts]
    else
      opts
    end
  end

  @spec request_headers(
          base_headers :: [{charlist(), charlist()}],
          compression :: :gzip | :none
        ) :: [{charlist(), charlist()}]
  defp request_headers(headers, :gzip), do: [{~c"content-encoding", ~c"gzip"} | headers]
  defp request_headers(headers, _compression), do: headers

  @spec maybe_compress(body :: binary(), compression :: :gzip | :none) :: binary()
  defp maybe_compress(body, :gzip), do: :zlib.gzip(body)
  defp maybe_compress(body, _compression), do: body
end
