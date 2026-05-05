defmodule Otel.Metrics.MetricExporter do
  @moduledoc """
  OTLP/HTTP exporter for metrics. Implements the MetricExporter
  behaviour expected by
  `Otel.Metrics.MetricReader.PeriodicExporting` — `init/1`,
  `export/2`, `force_flush/1`, `shutdown/1`.

  Delegates the actual POST to `Otel.OTLP.HTTP` with signal
  path `/v1/metrics`. See that module's moduledoc for the
  user-facing `:req_options` config surface (auth, TLS,
  timeouts, retry, etc.).

  `init/1` keeps no state — `Otel.OTLP.HTTP` reads
  `:req_options` from `Application.get_env/2` on every export,
  so test-time reconfiguration takes effect immediately.
  """

  @metrics_path "/v1/metrics"

  @type state :: %{}

  @spec init(config :: term()) :: {:ok, state()}
  def init(_config), do: {:ok, %{}}

  @spec export(
          metrics :: [Otel.Metrics.MetricReader.metric()],
          state :: state()
        ) :: :ok | :error
  def export([], _state), do: :ok

  def export(metrics, _state) do
    metrics
    |> Otel.OTLP.Encoder.encode_metrics()
    |> Otel.OTLP.HTTP.post(@metrics_path)
  end

  @spec force_flush(state :: state()) :: :ok
  def force_flush(_state), do: :ok

  @spec shutdown(state :: state()) :: :ok
  def shutdown(_state), do: :ok
end
