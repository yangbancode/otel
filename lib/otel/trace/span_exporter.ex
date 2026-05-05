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

  ## OTLP HTTP transport

  POSTs OTLP/protobuf via [`Req`](https://hex.pm/packages/req).
  User config is read from
  `Application.get_env(:otel, :req_options, [])` on every export
  and forwarded to `Req.post/1` — anything Req accepts (TLS,
  auth, timeouts, retry overrides, mock plugs) works.

  The SDK only forces `:body` (the encoded protobuf). Defaults
  via `Keyword.put_new`:

  - `:base_url` → `http://localhost:4318` if absent
  - `:url` → `/v1/traces` if absent
  - `:retry` → predicate matching the OTLP-spec retryable
    response codes (`opentelemetry-proto/docs/specification.md`
    L564-575: 429 / 502 / 503 / 504 SHOULD be retried, all
    other 4xx / 5xx MUST NOT) plus network-level exceptions.
    `Retry-After` is honored automatically by Req.
  - `:max_retries` → `4` (5 attempts including the first).
    The spec mandates exponential backoff with jitter
    (`opentelemetry-specification/specification/protocol/exporter.md`
    L182-202) but does *not* prescribe a specific number of
    attempts. `4` follows the Java OTLP SDK default
    (de-facto standard).
  - `content-type: application/x-protobuf` and `user-agent`
    headers merged into the user's `:headers`

  ## References

  - OTel Trace SDK §Batching processor: `opentelemetry-specification/specification/trace/sdk.md` L1086-L1118
  - OTel Trace SDK §SpanExporter: `opentelemetry-specification/specification/trace/sdk.md` L1119-L1207
  - OTLP retryable response codes: `opentelemetry-proto/docs/specification.md` L565-L573
  """

  use GenServer

  require Logger

  # OTel spec `trace/sdk.md` L1109-L1118 defaults.
  @scheduled_delay_ms 5_000
  @max_export_batch_size 512
  @export_timeout_ms 30_000

  @default_base_url "http://localhost:4318"
  @default_url "/v1/traces"

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
    |> Keyword.put_new(:url, @default_url)
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
    Logger.warning("OTLP trace export failed with HTTP #{status}")
    :error
  end

  defp handle_response({:error, exception}) do
    Logger.warning("OTLP trace export failed: #{inspect(exception)}")
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
