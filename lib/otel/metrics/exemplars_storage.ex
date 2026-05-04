defmodule Otel.Metrics.ExemplarsStorage do
  @moduledoc """
  ETS owner for the `:otel_exemplars` table — exemplar
  reservoirs keyed by aggregation key
  (spec `metrics/sdk.md` §Exemplar).

  Same `SpanStorage`-style GenServer-as-owner pattern as the
  other Metrics storage modules.
  """

  use GenServer

  @table :otel_exemplars

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
