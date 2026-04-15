defmodule Otel.SDK.Metrics.MetricReader do
  @moduledoc """
  MetricReader behaviour and collection pipeline.

  A MetricReader collects metrics from the SDK's aggregation state,
  runs async callbacks, and delivers collected data to an exporter.

  Collection produces a list of metric maps, each containing the
  stream identity, resource, scope, and data points.
  """

  @type metric :: %{
          name: String.t(),
          description: String.t(),
          unit: String.t(),
          scope: Otel.API.InstrumentationScope.t(),
          resource: Otel.SDK.Resource.t(),
          kind: Otel.SDK.Metrics.Instrument.kind(),
          datapoints: [Otel.SDK.Metrics.Aggregation.datapoint()]
        }

  @callback start_link(config :: map()) :: GenServer.on_start()
  @callback shutdown(server :: GenServer.server()) :: :ok | {:error, term()}
  @callback force_flush(server :: GenServer.server()) :: :ok | {:error, term()}

  @spec collect(config :: map()) :: [metric()]
  def collect(config) do
    Otel.SDK.Metrics.Meter.run_callbacks(config)

    streams = :ets.tab2list(config.streams_tab)

    streams
    |> Enum.map(fn {_key, stream} -> stream end)
    |> Enum.uniq_by(fn stream -> {stream.name, stream.instrument.scope} end)
    |> Enum.flat_map(fn stream -> collect_stream(config, stream) end)
  end

  @spec collect_stream(config :: map(), stream :: Otel.SDK.Metrics.Stream.t()) :: [metric()]
  defp collect_stream(config, stream) do
    stream_key = {stream.name, stream.instrument.scope}

    datapoints =
      stream.aggregation.collect(config.metrics_tab, stream_key, stream.aggregation_options)

    case datapoints do
      [] ->
        []

      points ->
        [
          %{
            name: stream.name,
            description: stream.description,
            unit: stream.instrument.unit,
            scope: stream.instrument.scope,
            resource: config.resource,
            kind: stream.instrument.kind,
            datapoints: points
          }
        ]
    end
  end
end
