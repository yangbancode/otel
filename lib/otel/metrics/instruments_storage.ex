defmodule Otel.Metrics.InstrumentsStorage do
  @moduledoc """
  ETS owner for the `:otel_instruments` table — one row per
  registered Instrument keyed by `{scope, downcased_name}`
  (spec `metrics/api.md` §Instrument identity L190-L191).

  A GenServer that owns the table so its lifetime matches the
  SDK supervisor and dies with it. The table is `public` with
  `read_concurrency` / `write_concurrency` so any process
  reads/writes without going through this server — the GenServer
  is not on the hot path. Same pattern as `Otel.Trace.SpanStorage`.
  """

  use GenServer

  @table :otel_instruments

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
