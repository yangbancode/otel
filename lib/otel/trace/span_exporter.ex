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
  under the hood). Read from `Application.get_env(:otel, :req_options, [])`
  on every export — no init-time caching, so test-time
  reconfiguration takes effect immediately.

  Retry uses an OTLP-specific predicate over Req's built-in retry
  mechanism — only 429 / 502 / 503 / 504 and network errors are
  retried, matching `opentelemetry-proto/docs/specification.md`
  §"Retryable Response Codes" L565-L573. Req's default delay
  function honors `Retry-After` automatically when the predicate
  returns true.

  ## Configuration

  Pass any [`Req.new/1`](https://hexdocs.pm/req/Req.html#new/1)
  option through `:req_options` — the SDK treats it as a thin
  wrapper:

      config :otel,
        req_options: [
          base_url: "https://otlp-gateway-prod-us-central-0.grafana.net/otlp",
          headers: %{
            "authorization" => "Basic " <> Base.encode64("instance:token")
          }
        ]

  The SDK forces `:url` (per-signal path, `/v1/traces`) and
  `:body` (encoded protobuf). It defaults `:base_url` to
  `http://localhost:4318` if omitted, and applies the OTLP
  retry predicate as `:retry` / `:max_retries` defaults
  (overridable via `:req_options` if needed for tests). All
  other options — `:connect_options` for TLS, `:receive_timeout`,
  `:plug` for mock injection, `:redirect`, `:cache`, etc. —
  fall through to Req unchanged.

  Two headers are merged into the user's headers (user wins on
  collision): `content-type: application/x-protobuf` and a
  `user-agent` carrying the SDK version.

  ## References

  - OTel Trace SDK §Batching processor: `opentelemetry-specification/specification/trace/sdk.md` L1086-L1118
  - OTel Trace SDK §SpanExporter: `opentelemetry-specification/specification/trace/sdk.md` L1119-L1207
  - OTLP Exporter §Retry: `opentelemetry-proto/docs/specification.md` L565-L611
  - Req options: <https://hexdocs.pm/req/Req.html#new/1>
  """

  use GenServer

  require Logger

  # OTel spec `trace/sdk.md` L1109-L1118 defaults.
  @scheduled_delay_ms 5_000
  @max_export_batch_size 512
  @export_timeout_ms 30_000

  @default_base_url "http://localhost:4318"
  @traces_path "/v1/traces"

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
    user_opts = Application.get_env(:otel, :req_options, [])

    user_opts
    |> Keyword.put_new(:base_url, @default_base_url)
    |> Keyword.put(:url, @traces_path)
    |> Keyword.put(:body, body)
    |> Keyword.put_new(:retry, &otlp_retry?/2)
    |> Keyword.put_new(:max_retries, 4)
    |> with_required_headers()
    |> Req.post()
    |> handle_response()
  end

  defp loop, do: Process.send_after(self(), :loop, @scheduled_delay_ms)

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
    Logger.warning("OTLP trace export failed with HTTP #{status}")
    :error
  end

  defp handle_response({:error, exception}) do
    Logger.warning("OTLP trace export failed: #{inspect(exception)}")
    :error
  end

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
