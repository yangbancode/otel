defmodule Otel.Metrics.MetricsStorage do
  @moduledoc """
  ETS owner for the `:otel_metrics` table — aggregated
  datapoints keyed by `{stream_name, scope, reader_id, attrs}`
  (spec `metrics/data-model.md` §Metric).

  Same `SpanStorage`-style GenServer-as-owner pattern as the
  other Metrics storage modules — table is `public` with
  concurrency flags so the recording / collection paths bypass
  the GenServer.
  """

  use GenServer

  @table :otel_metrics

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{}}
  end
end
