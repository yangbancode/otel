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

  ## OTLP transport

  HTTP POST via `:httpc` to the configured collector endpoint.
  Endpoint resolved from `Application.get_env(:otel, :exporter)[:endpoint]`
  on every export — no init-time caching, so test-time reconfiguration
  takes effect immediately.

  ## References

  - OTel Trace SDK §Batching processor: `opentelemetry-specification/specification/trace/sdk.md` L1086-L1118
  - OTel Trace SDK §SpanExporter: `opentelemetry-specification/specification/trace/sdk.md` L1119-L1207
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

    config = Application.get_env(:otel, :exporter, %{})
    body = maybe_compress(body, Map.get(config, :compression, :none))

    endpoint = resolve_endpoint(config)
    headers = resolve_headers(config, body)
    http_options = build_http_options(config, endpoint)

    Otel.OTLP.HTTP.Retry.request(
      {String.to_charlist(endpoint), headers, ~c"application/x-protobuf", body},
      http_options,
      []
    )
  end

  defp loop, do: Process.send_after(self(), :loop, @scheduled_delay_ms)

  # --- HTTP config (per-call lookup, no init caching) ---

  defp resolve_endpoint(config) do
    base = Map.get(config, :endpoint, @default_endpoint)
    String.trim_trailing(base, "/") <> @traces_path
  end

  defp resolve_headers(config, _body) do
    user_headers =
      config
      |> Map.get(:headers, %{})
      |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

    [{~c"user-agent", String.to_charlist(user_agent())} | user_headers]
  end

  defp user_agent, do: "Otel/#{Application.spec(:otel, :vsn)}"

  defp build_http_options(config, endpoint) do
    timeout = Map.get(config, :timeout, @default_timeout)
    ssl_options = build_ssl_options(endpoint, config)
    opts = [{:timeout, timeout}]
    if ssl_options != [], do: [{:ssl, ssl_options} | opts], else: opts
  end

  defp build_ssl_options(endpoint, config) do
    case Map.get(config, :ssl_options) do
      opts when is_list(opts) ->
        opts

      _ ->
        if String.starts_with?(endpoint, "https"),
          do: default_ssl_options(endpoint),
          else: []
    end
  end

  defp default_ssl_options(endpoint) do
    host = endpoint |> URI.parse() |> Map.get(:host, "localhost")

    [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(host),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]
  end

  defp maybe_compress(body, :gzip), do: :zlib.gzip(body)
  defp maybe_compress(body, _), do: body
end
