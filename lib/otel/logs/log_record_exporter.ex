defmodule Otel.Logs.LogRecordExporter do
  @moduledoc """
  Logs export pipeline — timer-driven take from
  `LogRecordStorage` + OTLP encode + HTTP POST. Single GenServer
  collapsing what was previously a separate `LogRecordProcessor`
  (queue + timer + drain) plus a passive HTTP-only Exporter.

  ## Lifecycle

  | Trigger | Action |
  |---|---|
  | `:loop` self-message every `@scheduled_delay_ms` | take one batch (`@max_export_batch_size`) of records, encode, POST |
  | `force_flush/1` | drain *all* records synchronously |
  | `terminate/2` | drain remaining records before exit |

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

  ## References

  - OTel Logs SDK §LogRecordProcessor: `opentelemetry-specification/specification/logs/sdk.md` L468-L545
  - OTel Logs SDK §LogRecordExporter: `opentelemetry-specification/specification/logs/sdk.md` L546-L660
  - OTLP retryable response codes: `opentelemetry-proto/docs/specification.md` L565-L573
  """

  use GenServer

  # Spec `logs/sdk.md` L538 §LogRecordProcessor `scheduledDelayMillis`:
  # "the delay interval in milliseconds between two consecutive
  # exports. The default value is `1000`." (Logs default differs
  # from trace's 5000.)
  @scheduled_delay_ms 1_000
  @max_export_batch_size 512
  @export_timeout_ms 30_000

  @default_base_url "http://localhost:4318"
  @default_url "/v1/logs"
  @content_type "application/x-protobuf"
  @user_agent "#{Mix.Project.config()[:app]}/#{Mix.Project.config()[:version]}"

  # --- Public API ---

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec force_flush(timeout :: timeout()) :: :ok
  def force_flush(timeout \\ @export_timeout_ms) do
    GenServer.call(__MODULE__, :force_flush, timeout)
  end

  # --- GenServer ---

  @impl true
  @spec init(opts :: term()) :: {:ok, map()}
  def init(_opts) do
    loop()
    {:ok, %{}}
  end

  @impl true
  @spec handle_info(message :: :loop, state :: map()) :: {:noreply, map()}
  def handle_info(:loop, state) do
    do_export()
    loop()
    {:noreply, state}
  end

  @impl true
  @spec handle_call(:force_flush, from :: GenServer.from(), state :: map()) ::
          {:reply, :ok, map()}
  def handle_call(:force_flush, _from, state) do
    export()
    {:reply, :ok, state}
  end

  @impl true
  @spec terminate(reason :: term(), state :: map()) :: :ok
  def terminate(_reason, _state) do
    export()
    :ok
  end

  # --- Private ---

  # Drain the storage until empty — one batch at a time so each
  # export stays under `@max_export_batch_size`.
  @spec export() :: :ok
  defp export do
    case do_export() do
      :ok -> :ok
      _ -> export()
    end
  end

  # Take one batch (≤ `@max_export_batch_size`) and POST it.
  # Returns `:ok` when storage was empty, or Req's
  # `{:ok, %Req.Response{}} | {:error, Exception.t()}` when an
  # export ran.
  @spec do_export() :: :ok | {:ok, Req.Response.t()} | {:error, Exception.t()}
  defp do_export do
    case Otel.Logs.LogRecordStorage.take(@max_export_batch_size) do
      [] ->
        :ok

      batch ->
        Req.new(
          method: :post,
          base_url: @default_base_url,
          url: @default_url,
          retry: &retry?/2
        )
        |> Req.merge(Application.get_env(:otel, :req_options, []))
        |> Req.merge(body: Otel.OTLP.Encoder.encode_logs(batch))
        |> Req.Request.put_new_header("content-type", @content_type)
        |> Req.Request.put_new_header("user-agent", @user_agent)
        |> Req.request()
    end
  end

  @spec loop() :: reference()
  defp loop, do: Process.send_after(self(), :loop, @scheduled_delay_ms)

  # OTLP retry predicate — `opentelemetry-proto/docs/specification.md`
  # §"Retryable Response Codes" L564-575: only the four listed
  # codes SHOULD be retried; "All other 4xx or 5xx ... MUST NOT
  # be retried". Hence the explicit `false` for any other
  # `%Req.Response{}` — Req's built-in `:transient` preset
  # retries 408 / 500 too and would violate that MUST NOT.
  #
  # Network / protocol failures arrive here as Exception structs
  # (Req.TransportError, Req.HTTPError, etc.) — retry on any.
  @spec retry?(
          request :: Req.Request.t(),
          response_or_exception :: Req.Response.t() | Exception.t()
        ) :: boolean()
  defp retry?(_request, %Req.Response{status: status})
       when status in [429, 502, 503, 504],
       do: true

  defp retry?(_request, %Req.Response{}), do: false

  defp retry?(_request, %{__exception__: true}), do: true
end
