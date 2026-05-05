defmodule Otel.Metrics.MetricExporter do
  @moduledoc """
  Metrics export pipeline — timer-driven snapshot of the per-table
  `XxxStorage` GenServers + OTLP encode + HTTP POST. Single
  GenServer collapsing what was previously a separate
  `Otel.Metrics.MetricReader.PeriodicExporting` GenServer
  (timer + collect) plus a passive HTTP-only `MetricExporter`
  module.

  Unlike `Otel.Trace.SpanExporter` and
  `Otel.Logs.LogRecordExporter` (which drain a queue),
  Metrics exports a snapshot of live state — the six
  `Otel.Metrics.{InstrumentsStorage, StreamsStorage,
  MetricsStorage, CallbacksStorage, ExemplarsStorage,
  ObservedAttrsStorage}` GenServers hold accumulating
  aggregation / exemplar / observed-attr state. `collect/1`
  walks the streams ETS table, runs registered observable
  callbacks, and returns one `metric()` per stream; the next
  collect tick reads the same state with fresh aggregation
  values.

  ## Lifecycle

  | Trigger | Action |
  |---|---|
  | `:loop` self-message every `@scheduled_delay_ms` | `collect/1` + encode + POST |
  | `force_flush/1` | force collect + encode + POST synchronously |
  | `terminate/2` | force collect + encode + POST before exit |

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

  ## Concurrency

  Spec `metrics/sdk.md` L1880-L1881 (Status: Stable) —
  *"Collect, ForceFlush (for periodic exporting MetricReader)
  and Shutdown MUST be safe to be called concurrently."*
  The single GenServer mailbox serialises `force_flush/1`
  against the timer-driven `:loop` message, satisfying the MUST.
  `collect/1` is a pure pull from ETS / `:persistent_term`
  state and is safe to call from any process.

  ## References

  - OTel Metrics SDK §MetricReader: `opentelemetry-specification/specification/metrics/sdk.md` L1280-L1442
  - OTel Metrics SDK §Periodic exporting MetricReader: `opentelemetry-specification/specification/metrics/sdk.md` L1443-L1500
  - OTel Metrics SDK §MetricExporter: `opentelemetry-specification/specification/metrics/sdk.md` L1530-L1660
  - OTLP retryable response codes: `opentelemetry-proto/docs/specification.md` L565-L573
  """

  use GenServer

  # OTel spec `metrics/sdk.md` L1450-L1453 §Periodic exporting
  # MetricReader: `exportIntervalMillis` default 60_000,
  # `exportTimeoutMillis` default 30_000.
  @scheduled_delay_ms 60_000
  @export_timeout_ms 30_000

  @default_base_url "http://localhost:4318"
  @default_url "/v1/metrics"
  @content_type "application/x-protobuf"
  @user_agent "#{Mix.Project.config()[:app]}/#{Mix.Project.config()[:version]}"

  @typedoc """
  One metric record produced by `collect/1` — the unit consumed by
  `Otel.OTLP.Encoder.encode_metrics/1`.
  """
  @type metric :: %{
          name: String.t(),
          description: String.t(),
          unit: String.t(),
          scope: Otel.InstrumentationScope.t(),
          resource: Otel.Resource.t(),
          kind: Otel.Metrics.Instrument.kind(),
          temporality: Otel.Metrics.Instrument.temporality() | nil,
          is_monotonic: boolean() | nil,
          datapoints: [Otel.Metrics.Aggregation.datapoint()]
        }

  # --- Public API ---

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec force_flush(timeout :: timeout()) :: :ok
  def force_flush(timeout \\ @export_timeout_ms) do
    GenServer.call(__MODULE__, :force_flush, timeout)
  end

  @doc """
  **SDK** — Walks the streams ETS table, runs registered
  observable callbacks, and returns one `metric()` per stream.

  Pure pull from ETS state — safe to invoke from any process.
  Tests pass a custom config map (e.g. delta `temporality_mapping`
  or `:exemplar_filter` override) to exercise paths the
  hardcoded `Otel.Metrics.meter_config/0` doesn't reach.
  """
  @spec collect(config :: map()) :: [metric()]
  def collect(config) do
    Otel.Metrics.Meter.run_callbacks(config)

    reader_id = Map.get(config, :reader_id)
    streams = :ets.tab2list(config.streams_tab)

    streams
    |> Enum.map(fn {_key, stream} -> stream end)
    |> Enum.filter(fn stream -> stream.reader_id == reader_id end)
    |> Enum.uniq_by(fn stream -> {stream.name, stream.instrument.scope} end)
    |> Enum.flat_map(fn stream -> collect_stream(config, stream) end)
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
    do_export()
    {:reply, :ok, state}
  end

  @impl true
  @spec terminate(reason :: term(), state :: map()) :: :ok
  def terminate(_reason, _state) do
    do_export()
    :ok
  end

  # --- Private ---

  # Snapshot collect → encode → POST. Returns `:ok` when the
  # snapshot was empty, or Req's `{:ok, %Req.Response{}} |
  # {:error, Exception.t()}` when an export ran.
  @spec do_export() :: :ok | {:ok, Req.Response.t()} | {:error, Exception.t()}
  defp do_export do
    case collect(Otel.Metrics.meter_config()) do
      [] ->
        :ok

      metrics ->
        Req.new(
          method: :post,
          base_url: @default_base_url,
          url: @default_url,
          retry: &retry?/2
        )
        |> Req.merge(Application.get_env(:otel, :req_options, []))
        |> Req.merge(body: Otel.OTLP.Encoder.encode_metrics(metrics))
        |> Req.Request.put_new_header("content-type", @content_type)
        |> Req.Request.put_new_header("user-agent", @user_agent)
        |> Req.request()
    end
  end

  @spec collect_stream(config :: map(), stream :: Otel.Metrics.Stream.t()) :: [metric()]
  defp collect_stream(config, stream) do
    stream_key = {stream.name, stream.instrument.scope}
    collect_opts = build_collect_opts(stream)

    datapoints =
      stream.aggregation.collect(config.metrics_tab, stream_key, collect_opts)

    case datapoints do
      [] ->
        []

      points ->
        points_with_exemplars = attach_exemplars(config, stream, points)
        {temporality, is_monotonic} = metric_type_info(stream)

        [
          %{
            name: stream.name,
            description: stream.description,
            unit: stream.instrument.unit,
            scope: stream.instrument.scope,
            resource: config.resource,
            kind: stream.instrument.kind,
            temporality: temporality,
            is_monotonic: is_monotonic,
            datapoints: points_with_exemplars
          }
        ]
    end
  end

  @spec build_collect_opts(stream :: Otel.Metrics.Stream.t()) :: map()
  defp build_collect_opts(stream) do
    stream.aggregation_options
    |> Map.put(:reader_id, stream.reader_id)
    |> Map.put(:temporality, stream.temporality)
  end

  @spec metric_type_info(stream :: Otel.Metrics.Stream.t()) ::
          {Otel.Metrics.Instrument.temporality() | nil, boolean() | nil}
  defp metric_type_info(stream) do
    case stream.instrument.kind do
      kind when kind in [:gauge, :observable_gauge] ->
        {nil, nil}

      kind ->
        {stream.temporality, Otel.Metrics.Instrument.monotonic?(kind)}
    end
  end

  @spec attach_exemplars(
          config :: map(),
          stream :: Otel.Metrics.Stream.t(),
          datapoints :: [Otel.Metrics.Aggregation.datapoint()]
        ) :: [Otel.Metrics.Aggregation.datapoint()]
  defp attach_exemplars(config, stream, datapoints) do
    exemplars_tab = Map.get(config, :exemplars_tab)

    if exemplars_tab == nil do
      datapoints
    else
      Enum.map(datapoints, fn dp ->
        agg_key = {stream.name, stream.instrument.scope, stream.reader_id, dp.attributes}
        collect_exemplar_for_datapoint(exemplars_tab, agg_key, dp)
      end)
    end
  end

  @spec collect_exemplar_for_datapoint(
          exemplars_tab :: :ets.table(),
          agg_key :: Otel.Metrics.Aggregation.agg_key(),
          dp :: Otel.Metrics.Aggregation.datapoint()
        ) :: map()
  defp collect_exemplar_for_datapoint(exemplars_tab, agg_key, dp) do
    case :ets.lookup(exemplars_tab, agg_key) do
      [{^agg_key, reservoir}] ->
        {exemplars, updated} = Otel.Metrics.Exemplar.Reservoir.collect(reservoir)
        :ets.insert(exemplars_tab, {agg_key, updated})
        Map.put(dp, :exemplars, exemplars)

      [] ->
        Map.put(dp, :exemplars, [])
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
