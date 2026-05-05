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

  ## References

  - OTel Trace SDK §Batching processor: `opentelemetry-specification/specification/trace/sdk.md` L1086-L1118
  - OTel Trace SDK §SpanExporter: `opentelemetry-specification/specification/trace/sdk.md` L1119-L1207
  - OTLP retryable response codes: `opentelemetry-proto/docs/specification.md` L565-L573
  """

  use GenServer

  # OTel spec `trace/sdk.md` L1109-L1118 defaults.
  @scheduled_delay_ms 5_000
  @max_export_batch_size 512
  @export_timeout_ms 30_000

  @default_base_url "http://localhost:4318"
  @default_url "/v1/traces"
  @content_type "application/x-protobuf"
  @user_agent "#{Mix.Project.config()[:app]}/#{Mix.Project.config()[:version]}"

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
    Application.get_env(:otel, :req_options, [])
    |> Keyword.put_new(:base_url, @default_base_url)
    |> Keyword.put_new(:url, @default_url)
    |> Keyword.put_new(:retry, &retry?/2)
    |> Keyword.put(:body, Otel.OTLP.Encoder.encode_traces(batch, Otel.Resource.build()))
    |> Req.new()
    |> Req.Request.put_new_header("content-type", @content_type)
    |> Req.Request.put_new_header("user-agent", @user_agent)
    |> Req.post()
  end

  defp loop, do: Process.send_after(self(), :loop, @scheduled_delay_ms)

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
