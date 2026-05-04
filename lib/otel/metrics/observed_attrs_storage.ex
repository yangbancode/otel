defmodule Otel.Metrics.ObservedAttrsStorage do
  @moduledoc """
  ETS owner for the `:otel_observed_attrs` table — first-observed
  `(stream, reader, attrs)` triples for asynchronous instruments.

  Tracks attribute sets for the spec `metrics/sdk.md` §"Asynchronous
  instrument cardinality limits" L864-L866 SHOULD: *"Aggregators of
  asynchronous instruments SHOULD prefer the first-observed
  attributes in the callback when limiting cardinality, regardless
  of temporality."* Entries survive delta-collect resets so the
  first N attribute sets ever observed pin to their original key
  forever; subsequent sets route to the overflow attribute.

  Not a spec-defined entity — SDK-internal companion to the
  cardinality MUST at L840. Same `SpanStorage`-style
  GenServer-as-owner pattern as the other Metrics storage modules.
  """

  use GenServer

  @table :otel_observed_attrs

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
