defmodule Otel.Logs.LogRecordExporter do
  @moduledoc """
  OTLP/HTTP exporter for log records. Implements the
  `LogRecordExporter` behaviour expected by
  `Otel.Logs.LogRecordProcessor` — `init/1`, `export/2`,
  `force_flush/1`, `shutdown/1`.

  ## OTLP HTTP transport

  POSTs OTLP/protobuf via [`Req`](https://hex.pm/packages/req).
  User config is read from
  `Application.get_env(:otel, :req_options, [])` on every export
  and forwarded to `Req.post/1` — anything Req accepts (TLS,
  auth, timeouts, retry overrides, mock plugs) works.

  The SDK only forces `:body` (the encoded protobuf). Defaults
  via `Keyword.put_new`:

  - `:base_url` → `http://localhost:4318` if absent
  - `:url` → `/v1/logs` if absent
  - `:retry` → predicate matching the OTLP-spec retryable
    response codes (`opentelemetry-proto/docs/specification.md`
    L564-575: 429 / 502 / 503 / 504 SHOULD be retried, all
    other 4xx / 5xx MUST NOT) plus network-level exceptions.
    Backoff strategy (exponential + jitter) and `Retry-After`
    honoring come from Req's default `:retry_delay`, which
    satisfies the spec MUST in
    `opentelemetry-specification/specification/protocol/exporter.md`
    L182-202.
  - `content-type: application/x-protobuf` and `user-agent`
    headers merged into the user's `:headers`

  `:max_retries` is left to Req's default (3 retries = 4
  attempts) — the OTLP spec mandates the *strategy* but not a
  specific attempt count.

  `init/1` keeps no state; config is read per export so
  test-time reconfiguration takes effect immediately.

  ## References

  - OTel Logs SDK §LogRecordExporter: `opentelemetry-specification/specification/logs/sdk.md` L420-L520
  - OTLP retryable response codes: `opentelemetry-proto/docs/specification.md` L565-L573
  """

  require Logger

  @default_base_url "http://localhost:4318"
  @default_url "/v1/logs"

  @type state :: %{}

  @spec init(config :: term()) :: {:ok, state()}
  def init(_config), do: {:ok, %{}}

  @spec export(
          log_records :: [Otel.Logs.LogRecord.t()],
          state :: state()
        ) :: :ok | :error
  def export([], _state), do: :ok

  def export(log_records, _state) do
    Application.get_env(:otel, :req_options, [])
    |> Keyword.put_new(:base_url, @default_base_url)
    |> Keyword.put_new(:url, @default_url)
    |> Keyword.put_new(:retry, &retry?/2)
    |> Keyword.put(:body, Otel.OTLP.Encoder.encode_logs(log_records))
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
    Logger.warning("OTLP log export failed with HTTP #{status}")
    :error
  end

  defp handle_response({:error, exception}) do
    Logger.warning("OTLP log export failed: #{inspect(exception)}")
    :error
  end

  # OTLP retry predicate — `opentelemetry-proto/docs/specification.md`
  # §"Retryable Response Codes" L564-575: only the four listed
  # codes SHOULD be retried; "All other 4xx or 5xx ... MUST NOT
  # be retried". Hence the explicit `false` for any other
  # `%Req.Response{}` — Req's built-in `:transient` preset
  # retries 408 / 500 too and would violate that MUST NOT.
  defp retry?(_request, %Req.Response{status: status})
       when status in [429, 502, 503, 504],
       do: true

  defp retry?(_request, %Req.Response{}), do: false

  defp retry?(_request, %{__exception__: true}), do: true

  defp retry?(_request, _), do: false
end
