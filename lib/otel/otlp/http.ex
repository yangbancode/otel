defmodule Otel.OTLP.HTTP do
  @moduledoc """
  Shared OTLP/HTTP POST helper for the trace, logs, and metrics
  exporters. Wraps [`Req`](https://hex.pm/packages/req) with
  OTel-specific defaults: per-signal default path, OTLP retry
  predicate, and `content-type` / `user-agent` headers.

  ## Configuration

  User config is `Application.get_env(:otel, :req_options, [])` —
  whatever keyword list goes there is passed straight to
  `Req.new/1` (and merged into `Req.post/1`). The helper only
  forces `:body` (the encoded protobuf the caller passes in);
  every other option is set with `Keyword.put_new` so user
  values win:

  | Key | SDK behavior | User overridable? |
  |---|---|---|
  | `:body` | always set to caller's encoded protobuf | ✗ |
  | `:base_url` | default `http://localhost:4318` if absent | ✓ |
  | `:url` | default per-signal path (e.g. `/v1/traces`) if absent | ✓ |
  | `:retry` | default `otlp_retry?/2` predicate (429/502/503/504 + network) | ✓ (e.g. `retry: false` for tests) |
  | `:max_retries` | default `4` (5 attempts including first) | ✓ |
  | headers `content-type`, `user-agent` | merged into user's `:headers`, user wins on collision | ✓ |

  Everything else — TLS via `:connect_options`, `:auth`,
  `:receive_timeout`, `:plug` for mock injection, redirects,
  caching, and any future Req feature — falls through unchanged.

  ## Retry

  The default `otlp_retry?/2` predicate matches the OTLP spec's
  retryable response codes (`opentelemetry-proto/docs/specification.md`
  §"Retryable Response Codes" L565-L573):

  - `429` Too Many Requests
  - `502` / `503` / `504` server errors
  - any network-level exception

  Other 4xx / 5xx responses are non-retryable. Req's default
  delay function honors a server-supplied `Retry-After` header
  automatically when the predicate returns `true`.
  """

  require Logger

  @default_base_url "http://localhost:4318"

  @doc """
  POST `body` (encoded OTLP protobuf) to `signal_path`
  (e.g. `"/v1/traces"`). Returns `:ok` on 2xx, `:error`
  otherwise (with a `Logger.warning/1` describing the failure).
  """
  @spec post(body :: binary(), signal_path :: String.t()) :: :ok | :error
  def post(body, signal_path) when is_binary(body) and is_binary(signal_path) do
    user_opts = Application.get_env(:otel, :req_options, [])

    user_opts
    |> Keyword.put_new(:base_url, @default_base_url)
    |> Keyword.put_new(:url, signal_path)
    |> Keyword.put(:body, body)
    |> Keyword.put_new(:retry, &otlp_retry?/2)
    |> Keyword.put_new(:max_retries, 4)
    |> with_required_headers()
    |> Req.post()
    |> handle_response()
  end

  defp with_required_headers(opts) do
    required = %{
      "content-type" => "application/x-protobuf",
      "user-agent" => user_agent()
    }

    Keyword.update(opts, :headers, required, fn user_headers ->
      Map.merge(required, normalize_headers(user_headers))
    end)
  end

  defp normalize_headers(headers) when is_map(headers),
    do: Map.new(headers, fn {k, v} -> {to_string(k), to_string(v)} end)

  defp normalize_headers(headers) when is_list(headers),
    do: Map.new(headers, fn {k, v} -> {to_string(k), to_string(v)} end)

  defp user_agent, do: "Otel/#{Application.spec(:otel, :vsn)}"

  defp handle_response({:ok, %Req.Response{status: status}}) when status in 200..299, do: :ok

  defp handle_response({:ok, %Req.Response{status: status}}) do
    Logger.warning("OTLP export failed with HTTP #{status}")
    :error
  end

  defp handle_response({:error, exception}) do
    Logger.warning("OTLP export failed: #{inspect(exception)}")
    :error
  end

  # OTLP retry predicate — `protocol/exporter.md` §"Retryable
  # Response Codes" L565-L573.
  defp otlp_retry?(_request, %Req.Response{status: status})
       when status in [429, 502, 503, 504],
       do: true

  defp otlp_retry?(_request, %Req.Response{}), do: false

  defp otlp_retry?(_request, %{__exception__: true}), do: true

  defp otlp_retry?(_request, _), do: false
end
