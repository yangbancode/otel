defmodule Otel.OTLP.Trace.SpanExporter.HTTP do
  @moduledoc """
  OTLP HTTP Exporter for traces.

  Exports spans as binary protobuf over HTTP POST to an OTLP endpoint.
  Implements the SpanExporter behaviour.

  Default endpoint: http://localhost:4318/v1/traces

  ## Environment Variables

  Configuration priority: signal-specific env > general env > code config > defaults.

  | Signal-specific | General | Default |
  |---|---|---|
  | `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318` |
  | `OTEL_EXPORTER_OTLP_TRACES_HEADERS` | `OTEL_EXPORTER_OTLP_HEADERS` | none |
  | `OTEL_EXPORTER_OTLP_TRACES_COMPRESSION` | `OTEL_EXPORTER_OTLP_COMPRESSION` | none |
  | `OTEL_EXPORTER_OTLP_TRACES_TIMEOUT` | `OTEL_EXPORTER_OTLP_TIMEOUT` | 10000 ms |

  ## SSL/TLS

  For HTTPS endpoints, SSL certificate verification is enabled by default
  using system CA certificates (`:public_key.cacerts_get/0`).

  Custom SSL options can be provided via the `:ssl_options` config key.

  ## Retry

  Transient errors are retried with exponential backoff and
  jitter per `protocol/exporter.md` §Retry L181-L183. Retry
  behavior is delegated to `Otel.OTLP.HTTP.Retry`; defaults
  match the Java OTLP SDK (5 attempts, 1s → 5s capped, 1.5x
  multiplier, ±20% jitter). Override via the `:retry_opts`
  config key.
  """

  @behaviour Otel.SDK.Trace.SpanExporter

  @default_endpoint "http://localhost:4318"
  @traces_path "/v1/traces"
  @default_timeout 10_000

  @spec init(config :: term()) :: {:ok, Otel.SDK.Trace.SpanExporter.state()} | :ignore
  @impl true
  def init(config) do
    endpoint = resolve_endpoint(config)
    headers = resolve_headers(config)
    compression = resolve_compression(config)
    timeout = resolve_timeout(config)
    ssl_options = build_ssl_options(endpoint, config)
    retry_opts = Map.get(config, :retry_opts, %{})

    {:ok,
     %{
       endpoint: endpoint,
       headers: headers,
       compression: compression,
       timeout: timeout,
       ssl_options: ssl_options,
       retry_opts: retry_opts
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
    body = Otel.OTLP.Encoder.encode_traces(spans, resource)
    body = maybe_compress(body, state.compression)

    headers = request_headers(state.headers, state.compression)
    url = String.to_charlist(state.endpoint)
    http_options = build_http_options(state)

    case Otel.OTLP.HTTP.Retry.request(
           {url, headers, ~c"application/x-protobuf", body},
           http_options,
           [],
           state.retry_opts
         ) do
      :ok -> :ok
      {:error, _reason} -> :error
    end
  end

  @spec shutdown(state :: Otel.SDK.Trace.SpanExporter.state()) :: :ok
  @impl true
  def shutdown(_state), do: :ok

  # No internal buffering — every `export/3` is a synchronous
  # HTTP POST. Force-flush is a no-op contract for the
  # processor → exporter chain.
  @spec force_flush(state :: Otel.SDK.Trace.SpanExporter.state()) :: :ok
  @impl true
  def force_flush(_state), do: :ok

  # --- Env var resolution (signal-specific > general > code config > default) ---

  @spec resolve_endpoint(config :: map()) :: String.t()
  defp resolve_endpoint(config) do
    case resolve_env("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "OTEL_EXPORTER_OTLP_ENDPOINT") do
      {value, :signal} ->
        value

      {value, :general} ->
        String.trim_trailing(value, "/") <> @traces_path

      nil ->
        String.trim_trailing(Map.get(config, :endpoint, @default_endpoint), "/") <> @traces_path
    end
  end

  @spec resolve_headers(config :: map()) :: [{charlist(), charlist()}]
  defp resolve_headers(config) do
    user_headers =
      case resolve_env_value("OTEL_EXPORTER_OTLP_TRACES_HEADERS", "OTEL_EXPORTER_OTLP_HEADERS") do
        nil ->
          config
          |> Map.get(:headers, %{})
          |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

        header_string ->
          parse_headers(header_string)
      end

    [{~c"user-agent", String.to_charlist(user_agent())} | user_headers]
  end

  @spec user_agent() :: String.t()
  defp user_agent, do: "Otel/#{Application.spec(:otel, :vsn)}"

  @spec resolve_compression(config :: map()) :: :gzip | :none
  defp resolve_compression(config) do
    case resolve_env_value(
           "OTEL_EXPORTER_OTLP_TRACES_COMPRESSION",
           "OTEL_EXPORTER_OTLP_COMPRESSION"
         ) do
      "gzip" -> :gzip
      nil -> Map.get(config, :compression, :none)
      _ -> :none
    end
  end

  @spec resolve_timeout(config :: map()) :: pos_integer()
  defp resolve_timeout(config) do
    case resolve_env_value("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT", "OTEL_EXPORTER_OTLP_TIMEOUT") do
      nil ->
        Map.get(config, :timeout, @default_timeout)

      value ->
        case Integer.parse(value) do
          {ms, ""} -> ms
          _ -> @default_timeout
        end
    end
  end

  # --- Env var helpers ---

  @spec resolve_env(signal_var :: String.t(), general_var :: String.t()) ::
          {String.t(), :signal | :general} | nil
  defp resolve_env(signal_var, general_var) do
    case get_env(signal_var) do
      nil ->
        case get_env(general_var) do
          nil -> nil
          value -> {value, :general}
        end

      value ->
        {value, :signal}
    end
  end

  @spec resolve_env_value(signal_var :: String.t(), general_var :: String.t()) ::
          String.t() | nil
  defp resolve_env_value(signal_var, general_var) do
    get_env(signal_var) || get_env(general_var)
  end

  @spec get_env(name :: String.t()) :: String.t() | nil
  defp get_env(name) do
    case System.get_env(name) do
      nil -> nil
      "" -> nil
      value -> String.trim(value)
    end
  end

  # --- Header parsing ---

  @spec parse_headers(header_string :: String.t()) :: [{charlist(), charlist()}]
  defp parse_headers(header_string) do
    header_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(fn pair ->
      case String.split(pair, "=", parts: 2) do
        [key, value] when key != "" ->
          [{String.to_charlist(String.trim(key)), String.to_charlist(String.trim(value))}]

        _ ->
          []
      end
    end)
  end

  # --- SSL ---

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

  # --- HTTP options ---

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
  defp request_headers(headers, :gzip), do: [{~c"content-encoding", ~c"gzip"} | headers]
  defp request_headers(headers, _compression), do: headers

  @spec maybe_compress(body :: binary(), compression :: :gzip | :none) :: binary()
  defp maybe_compress(body, :gzip), do: :zlib.gzip(body)
  defp maybe_compress(body, _compression), do: body
end
