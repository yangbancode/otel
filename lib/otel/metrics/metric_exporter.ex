defmodule Otel.Metrics.MetricExporter do
  @moduledoc """
  OTLP/HTTP exporter for metrics. Implements the MetricExporter
  behaviour expected by
  `Otel.Metrics.MetricReader.PeriodicExporting` — `init/1`,
  `export/2`, `force_flush/1`, `shutdown/1`.

  ## OTLP HTTP transport

  POSTs OTLP/protobuf via [`Req`](https://hex.pm/packages/req).
  User config is read from
  `Application.get_env(:otel, :req_options, [])` on every export
  and forwarded to `Req.post/1` — anything Req accepts (TLS,
  auth, timeouts, retry overrides, mock plugs) works.

  The SDK only forces `:body` (the encoded protobuf). Defaults
  via `Keyword.put_new`:

  - `:base_url` → `http://localhost:4318` if absent
  - `:url` → `/v1/metrics` if absent
  - `:retry` → OTLP-spec predicate (429 / 502 / 503 / 504 +
    network errors; `Retry-After` honored automatically by Req)
  - `:max_retries` → `4` (5 attempts including the first)
  - `content-type: application/x-protobuf` and `user-agent`
    headers merged into the user's `:headers`

  `init/1` keeps no state; config is read per export so
  test-time reconfiguration takes effect immediately.

  ## References

  - OTel Metrics SDK §MetricExporter: `opentelemetry-specification/specification/metrics/sdk.md` L1530-L1660
  - OTLP retryable response codes: `opentelemetry-proto/docs/specification.md` L565-L573
  """

  require Logger

  @default_base_url "http://localhost:4318"
  @metrics_path "/v1/metrics"

  @type state :: %{}

  @spec init(config :: term()) :: {:ok, state()}
  def init(_config), do: {:ok, %{}}

  @spec export(
          metrics :: [Otel.Metrics.MetricReader.metric()],
          state :: state()
        ) :: :ok | :error
  def export([], _state), do: :ok

  def export(metrics, _state) do
    body = Otel.OTLP.Encoder.encode_metrics(metrics)
    user_opts = Application.get_env(:otel, :req_options, [])

    user_opts
    |> Keyword.put_new(:base_url, @default_base_url)
    |> Keyword.put_new(:url, @metrics_path)
    |> Keyword.put(:body, body)
    |> Keyword.put_new(:retry, &otlp_retry?/2)
    |> Keyword.put_new(:max_retries, 4)
    |> with_required_headers()
    |> Req.post()
    |> handle_response()
  end

  @spec force_flush(state :: state()) :: :ok
  def force_flush(_state), do: :ok

  @spec shutdown(state :: state()) :: :ok
  def shutdown(_state), do: :ok

  # --- Private ---

  defp with_required_headers(opts) do
    required = %{
      "content-type" => "application/x-protobuf",
      "user-agent" => "Otel/#{Application.spec(:otel, :vsn)}"
    }

    Keyword.update(opts, :headers, required, fn user_headers ->
      Map.merge(required, normalize_headers(user_headers))
    end)
  end

  defp normalize_headers(headers) when is_map(headers),
    do: Map.new(headers, fn {k, v} -> {to_string(k), to_string(v)} end)

  defp normalize_headers(headers) when is_list(headers),
    do: Map.new(headers, fn {k, v} -> {to_string(k), to_string(v)} end)

  defp handle_response({:ok, %Req.Response{status: status}}) when status in 200..299, do: :ok

  defp handle_response({:ok, %Req.Response{status: status}}) do
    Logger.warning("OTLP metric export failed with HTTP #{status}")
    :error
  end

  defp handle_response({:error, exception}) do
    Logger.warning("OTLP metric export failed: #{inspect(exception)}")
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
