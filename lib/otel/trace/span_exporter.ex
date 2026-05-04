defmodule Otel.Trace.SpanExporter do
  @moduledoc """
  Trace export pipeline — timer-driven take from `SpanStorage` +
  OTLP encode + HTTP POST. Single GenServer absorbing what was
  previously split between `SpanProcessor` (queue + timer + drain)
  and a HTTP-only Exporter.

  ## Lifecycle

  | Trigger | Action |
  |---|---|
  | `:loop` self-message every `@scheduled_delay_ms` | take one batch (`@max_export_batch_size`) of `:completed` spans, encode, POST |
  | `force_flush/1` | drain *all* completed spans synchronously |
  | `terminate/2` (Application stop) | drain remaining spans before exit |

  ## OTLP transport — Req

  HTTP POST via [`Req`](https://hex.pm/packages/req) (Finch / Mint
  under the hood). Endpoint and related options are read from
  `Application.get_env(:otel, ...)` on every export — no init-time
  caching, so test-time reconfiguration takes effect immediately.

  Retry uses an OTLP-specific predicate over Req's built-in retry
  mechanism — only 429 / 502 / 503 / 504 and network errors are
  retried, matching `opentelemetry-proto/docs/specification.md`
  §"Retryable Response Codes" L565-L573. Req's default delay
  function honors `Retry-After` automatically when the predicate
  returns true.

  ## Configuration

      config :otel,
        endpoint: "http://localhost:4318",
        headers: %{"authorization" => "Bearer ..."},
        ssl: [verify: :verify_peer, cacertfile: "/path/to/ca.pem"],
        compression: :gzip

  All keys are optional. Defaults are HTTP `localhost:4318`, no
  custom headers, OTP system trust store for HTTPS, no
  compression.

  ## References

  - OTel Trace SDK §Batching processor: `opentelemetry-specification/specification/trace/sdk.md` L1086-L1118
  - OTel Trace SDK §SpanExporter: `opentelemetry-specification/specification/trace/sdk.md` L1119-L1207
  - OTLP Exporter §Retry: `opentelemetry-proto/docs/specification.md` L565-L611
  """

  use GenServer

  require Logger

  # OTel spec `trace/sdk.md` L1109-L1118 defaults.
  @scheduled_delay_ms 5_000
  @max_export_batch_size 512
  @export_timeout_ms 30_000

  @default_endpoint "http://localhost:4318"
  @traces_path "/v1/traces"
  @default_timeout 10_000

  # --- Public API ---

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec force_flush(timeout :: timeout()) :: :ok | {:error, term()}
  def force_flush(timeout \\ @export_timeout_ms) do
    GenServer.call(__MODULE__, :force_flush, timeout)
  catch
    :exit, {:noproc, _} -> {:error, :already_shutdown}
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  # --- GenServer ---

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    loop()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:loop, state) do
    drain_one_batch()
    loop()
    {:noreply, state}
  end

  @impl true
  def handle_call(:force_flush, _from, state) do
    drain_all()
    {:reply, :ok, state}
  end

  # Application stop / supervisor shutdown — drain remaining
  # completed spans before exit. Wrapped in try/catch so exporter
  # failure doesn't crash the supervisor (lifecycle hook exempt
  # from happy-path rule).
  @impl true
  def terminate(_reason, _state) do
    try do
      drain_all()
    catch
      _kind, _reason -> :ok
    end

    :ok
  end

  # --- Private ---

  defp drain_one_batch do
    case Otel.Trace.SpanStorage.take_completed(@max_export_batch_size) do
      [] -> :ok
      batch -> do_export(batch)
    end
  end

  defp drain_all do
    case Otel.Trace.SpanStorage.take_completed(@max_export_batch_size) do
      [] ->
        :ok

      batch ->
        do_export(batch)
        drain_all()
    end
  end

  defp do_export(batch) do
    body = Otel.OTLP.Encoder.encode_traces(batch, Otel.Resource.build())

    endpoint = Application.get_env(:otel, :endpoint, @default_endpoint)
    user_headers = Application.get_env(:otel, :headers, %{})
    ssl_opts = Application.get_env(:otel, :ssl, [])
    compression = Application.get_env(:otel, :compression, :none)
    timeout = Application.get_env(:otel, :timeout, @default_timeout)

    body = maybe_compress(body, compression)
    headers = build_headers(user_headers, compression)
    url = String.trim_trailing(endpoint, "/") <> @traces_path

    opts =
      [
        body: body,
        headers: headers,
        receive_timeout: timeout,
        retry: &otlp_retry?/2,
        max_retries: 4
      ]
      |> maybe_add_connect_options(ssl_opts)

    case Req.post(url, opts) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("OTLP trace export failed with HTTP #{status}")
        :error

      {:error, exception} ->
        Logger.warning("OTLP trace export failed: #{inspect(exception)}")
        :error
    end
  end

  defp loop, do: Process.send_after(self(), :loop, @scheduled_delay_ms)

  defp build_headers(user_headers, compression) do
    %{
      "user-agent" => user_agent(),
      "content-type" => "application/x-protobuf"
    }
    |> maybe_add_compression_header(compression)
    |> Map.merge(stringify_headers(user_headers))
  end

  defp stringify_headers(headers) when is_map(headers) do
    Map.new(headers, fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp maybe_add_compression_header(headers, :gzip),
    do: Map.put(headers, "content-encoding", "gzip")

  defp maybe_add_compression_header(headers, _), do: headers

  defp user_agent, do: "Otel/#{Application.spec(:otel, :vsn)}"

  defp maybe_add_connect_options(opts, []), do: opts

  defp maybe_add_connect_options(opts, ssl_opts) when is_list(ssl_opts),
    do: Keyword.put(opts, :connect_options, transport_opts: ssl_opts)

  defp maybe_compress(body, :gzip), do: :zlib.gzip(body)
  defp maybe_compress(body, _), do: body

  # OTLP retry predicate — `protocol/exporter.md` §"Retryable
  # Response Codes" L565-L573:
  # - 429 / 502 / 503 / 504 → retry (Retry-After honored by Req)
  # - other 4xx/5xx        → non-retryable, fail
  # - connection errors    → retry
  defp otlp_retry?(_request, %Req.Response{status: status})
       when status in [429, 502, 503, 504],
       do: true

  defp otlp_retry?(_request, %Req.Response{}), do: false

  defp otlp_retry?(_request, %{__exception__: true}), do: true

  defp otlp_retry?(_request, _), do: false
end
