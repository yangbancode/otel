defmodule Otel.Metrics.CallbacksStorage do
  @moduledoc """
  ETS owner for the named ETS table — registered
  observable-instrument callbacks
  (spec `metrics/api.md` §Asynchronous Instrument API).

  `:bag` because a single registration ref may attach the same
  callback to multiple instruments (multi-instrument
  `register_callback/4`). Same `SpanStorage`-style
  GenServer-as-owner pattern as the other Metrics storage
  modules.
  """

  use GenServer

  @table __MODULE__

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
