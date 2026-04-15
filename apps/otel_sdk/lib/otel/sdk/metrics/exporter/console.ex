defmodule Otel.SDK.Metrics.Exporter.Console do
  @moduledoc """
  Console exporter for metrics debugging.

  Outputs metrics to stdout in human-readable format.
  Not recommended for production use.
  """

  @behaviour Otel.SDK.Metrics.MetricExporter

  @impl true
  @spec init(config :: term()) :: {:ok, Otel.SDK.Metrics.MetricExporter.state()}
  def init(config), do: {:ok, config}

  @impl true
  @spec export(
          metrics :: [Otel.SDK.Metrics.MetricReader.metric()],
          state :: Otel.SDK.Metrics.MetricExporter.state()
        ) :: :ok
  def export(metrics, _state) do
    Enum.each(metrics, fn metric ->
      IO.puts(format_metric(metric))
    end)

    :ok
  end

  @impl true
  @spec force_flush(state :: Otel.SDK.Metrics.MetricExporter.state()) :: :ok
  def force_flush(_state), do: :ok

  @impl true
  @spec shutdown(state :: Otel.SDK.Metrics.MetricExporter.state()) :: :ok
  def shutdown(_state), do: :ok

  @spec format_metric(metric :: Otel.SDK.Metrics.MetricReader.metric()) :: String.t()
  defp format_metric(metric) do
    points =
      Enum.map_join(metric.datapoints, "\n  ", fn dp ->
        "#{inspect(dp.attributes)} => #{format_value(dp.value)}"
      end)

    "[otel] #{metric.name} (#{metric.kind}) unit=#{metric.unit} scope=#{metric.scope.name}\n  #{points}"
  end

  @spec format_value(value :: term()) :: String.t()
  defp format_value(%{bucket_counts: counts, sum: sum, count: count, min: min, max: max}) do
    "histogram{count=#{count}, sum=#{sum}, min=#{min}, max=#{max}, buckets=#{inspect(counts)}}"
  end

  defp format_value(value), do: inspect(value)
end
