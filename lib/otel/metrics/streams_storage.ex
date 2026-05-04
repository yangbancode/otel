defmodule Otel.Metrics.StreamsStorage do
  @moduledoc """
  ETS owner for the `:otel_streams` table — one row per
  `(instrument_key, reader_id)` Stream
  (spec `metrics/sdk.md` §Stream).

  `:bag` because each instrument may produce multiple streams
  (one per reader's temporality mapping). Same `SpanStorage`-style
  GenServer-as-owner pattern as the other Metrics storage
  modules — table is `public` with concurrency flags so producers
  bypass the GenServer.
  """

  use GenServer

  @table :otel_streams

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :bag,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{}}
  end
end
