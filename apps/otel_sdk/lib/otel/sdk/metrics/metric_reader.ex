defmodule Otel.SDK.Metrics.MetricReader do
  @moduledoc """
  MetricReader behaviour and collection pipeline.

  A MetricReader collects metrics from the SDK's aggregation state,
  runs async callbacks, and delivers collected data to an exporter.

  Collection produces a list of metric maps, each containing the
  stream identity, resource, scope, and data points.

  ## Concurrency

  Spec `metrics/sdk.md` L1880-L1881 (Status: Stable) —
  *"Collect, ForceFlush (for periodic exporting MetricReader)
  and Shutdown MUST be safe to be called concurrently."*
  Implementing modules MUST be safe for concurrent invocation
  of these three callbacks. The built-in
  `Otel.SDK.Metrics.MetricReader.PeriodicExporting` serialises
  via its GenServer mailbox, satisfying the MUST.

  ## Deferred Development-status features

  - **MetricFilter.** Spec `metrics/sdk.md` L1308 (Status:
    Development) describes a `MetricFilter` applied to metrics
    and attributes during `MetricReader#Collect`. Not
    implemented — no `:metric_filter` field on reader configs;
    `MetricProducer.produce/1` callback has no filter
    parameter. Waits for spec stabilisation.
  """

  @type metric :: %{
          name: String.t(),
          description: String.t(),
          unit: String.t(),
          scope: Otel.API.InstrumentationScope.t(),
          resource: Otel.SDK.Resource.t(),
          kind: Otel.API.Metrics.Instrument.kind(),
          temporality: Otel.API.Metrics.Instrument.temporality() | nil,
          is_monotonic: boolean() | nil,
          datapoints: [Otel.SDK.Metrics.Aggregation.datapoint()]
        }

  @typedoc """
  Reader-implementer config — the value passed to a reader's
  `start_link/1` callback. Each implementation defines its own
  shape; the alias names the boundary so callers (notably
  `Otel.SDK.Metrics.MeterProvider`) can refer to it in @specs
  rather than the bare `map()` literal.
  """
  @type config :: map()

  @callback start_link(config :: config()) :: GenServer.on_start()
  @callback shutdown(server :: GenServer.server()) :: :ok | {:error, term()}
  @callback force_flush(server :: GenServer.server()) :: :ok | {:error, term()}

  @spec collect(config :: config()) :: [metric()]
  def collect(config) do
    Otel.SDK.Metrics.Meter.run_callbacks(config)

    reader_id = Map.get(config, :reader_id)
    streams = :ets.tab2list(config.streams_tab)

    streams
    |> Enum.map(fn {_key, stream} -> stream end)
    |> Enum.filter(fn stream -> stream.reader_id == reader_id end)
    |> Enum.uniq_by(fn stream -> {stream.name, stream.instrument.scope} end)
    |> Enum.flat_map(fn stream -> collect_stream(config, stream) end)
  end

  @spec collect_stream(config :: config(), stream :: Otel.SDK.Metrics.Stream.t()) :: [metric()]
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

  @spec build_collect_opts(stream :: Otel.SDK.Metrics.Stream.t()) :: map()
  defp build_collect_opts(stream) do
    stream.aggregation_options
    |> Map.put(:reader_id, stream.reader_id)
    |> Map.put(:temporality, stream.temporality)
  end

  @spec metric_type_info(stream :: Otel.SDK.Metrics.Stream.t()) ::
          {Otel.API.Metrics.Instrument.temporality() | nil, boolean() | nil}
  defp metric_type_info(stream) do
    case stream.instrument.kind do
      kind when kind in [:gauge, :observable_gauge] ->
        {nil, nil}

      kind ->
        {stream.temporality, Otel.API.Metrics.Instrument.monotonic?(kind)}
    end
  end

  @spec attach_exemplars(
          config :: config(),
          stream :: Otel.SDK.Metrics.Stream.t(),
          datapoints :: [Otel.SDK.Metrics.Aggregation.datapoint()]
        ) :: [Otel.SDK.Metrics.Aggregation.datapoint()]
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
          agg_key :: term(),
          dp :: Otel.SDK.Metrics.Aggregation.datapoint()
        ) :: map()
  defp collect_exemplar_for_datapoint(exemplars_tab, agg_key, dp) do
    case :ets.lookup(exemplars_tab, agg_key) do
      [{^agg_key, reservoir}] ->
        {exemplars, updated} = Otel.SDK.Metrics.Exemplar.Reservoir.collect_from(reservoir)
        :ets.insert(exemplars_tab, {agg_key, updated})
        Map.put(dp, :exemplars, exemplars)

      [] ->
        Map.put(dp, :exemplars, [])
    end
  end
end
