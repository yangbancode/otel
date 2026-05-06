defmodule Otel.Logs.LogRecordStorage do
  @moduledoc """
  ETS-backed FIFO queue for log records awaiting export.

  Each row is `{key, %Otel.Logs.LogRecord{}, inserted_at_ms}`
  where the key is `:erlang.unique_integer([:positive])` — a
  positive integer guaranteed to be unique within the BEAM
  lifetime — and `inserted_at_ms` is the millisecond timestamp
  stamped at `insert/1` time, used solely by the sweep loop.
  The underlying table is `:set` (hash-based), matching
  `Otel.Trace.SpanStorage`'s shape and giving O(1) insert in the
  hot emit path. Take order is hash-iteration order (not emission
  order); this is fine because each log record carries its own
  `timestamp` / `observed_timestamp` and the collector orders by
  those.

  Logs are atomic events — there is no `:active` / `:completed`
  lifecycle like spans. Records enter via `insert/1` and leave
  via `take/1` when the exporter drains them.

  ## Public API

  | Function | Role |
  |---|---|
  | `insert/1` | enqueue a log record (back-pressure aware) |
  | `take/1` | take + delete a batch of oldest records (Exporter only) |

  Mutation flow used by `Otel.Logs.Logger`:

      Otel.Logs.LogRecordStorage.insert(record)

  No `get` or `update` — log records are immutable once enqueued.

  ## Concurrency

  Multi-writer + single-reader (the Exporter):

  - `insert/1` runs on the caller process and writes to ETS
    directly (`write_concurrency` makes this lock-free).
  - `take/1` is called only by `Otel.Logs.LogRecordExporter`
    (single reader — no take/insert races).

  ## Backpressure

  `insert/1` silently drops the record when the ETS table is
  already at `@max_queue_size`, matching the spec's
  `maxQueueSize` parameter for the Batching processor
  (`logs/sdk.md` L540-L541 *"After the size is reached logs are
  dropped"*). Drop is a normal lifecycle event, not a failure
  — callers don't branch on the result.

  ## Sweep — stale records

  The GenServer runs a self-scheduled sweep every
  `@sweep_interval_ms` (10 minutes) that issues a single
  `:ets.select_delete/2` removing rows whose `inserted_at_ms`
  (row position 3) is older than `@log_record_ttl_ms` (30
  minutes). This is the safety net for records that never get
  drained — if `Otel.Logs.LogRecordExporter` is dead or hung,
  records would otherwise pile up until the `@max_queue_size`
  backpressure starts dropping fresh records. With the sweep,
  the oldest stale records age out instead so fresh inserts
  keep landing.

  Defaults match `Otel.Trace.SpanStorage`'s sweeper for symmetry.
  Sweep strategy is `drop` only — exporting half-aged records
  serves no spec purpose.

  ## References

  - OTel Logs SDK §LogRecordProcessor: `opentelemetry-specification/specification/logs/sdk.md` L468-L545
  - Erlang `:erlang.unique_integer/1`: <https://www.erlang.org/doc/man/erlang#unique_integer-1>
  """

  use GenServer

  @table __MODULE__
  # Spec `logs/sdk.md` L540 §LogRecordProcessor `maxQueueSize`:
  # "the maximum queue size. After the size is reached logs are
  # dropped. The default value is `2048`."
  @max_queue_size 2_048

  # Sweep cadence and TTL — defaults mirror
  # `Otel.Trace.SpanStorage`'s sweeper (10-minute interval,
  # 30-minute TTL).
  @sweep_interval_ms :timer.minutes(10)
  @log_record_ttl_ms :timer.minutes(30)

  # --- Client API ---

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Enqueue a log record. Always returns `:ok` — silent drop when
  the table is at `@max_queue_size` (spec `logs/sdk.md` L540-L541
  *"After the size is reached logs are dropped"*: drop is a
  normal lifecycle event, not a failure).
  """
  @spec insert(log_record :: Otel.Logs.LogRecord.t()) :: :ok
  def insert(%Otel.Logs.LogRecord{} = record) do
    case :ets.info(@table, :size) do
      n when n >= @max_queue_size ->
        :ok

      _ ->
        key = :erlang.unique_integer([:positive])
        inserted_at = System.system_time(:millisecond)
        :ets.insert(@table, {key, record, inserted_at})
        :ok
    end
  end

  @doc """
  Take up to `n` log records, deleting them from the table.
  Records come back in hash-iteration order (not emission
  order). Called only by `Otel.Logs.LogRecordExporter` (single
  reader).
  """
  @spec take(n :: pos_integer()) :: [Otel.Logs.LogRecord.t()]
  def take(n) when n > 0 do
    spec = [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}]

    case :ets.select(@table, spec, n) do
      :"$end_of_table" ->
        []

      {pairs, _continuation} ->
        records = Enum.map(pairs, fn {_key, record} -> record end)
        Enum.each(pairs, fn {key, _} -> :ets.delete(@table, key) end)
        records
    end
  end

  # --- Server Callbacks ---

  @impl true
  @spec init(opts :: keyword()) :: {:ok, atom()}
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      {:write_concurrency, true},
      {:read_concurrency, true}
    ])

    loop()
    {:ok, @table}
  end

  @impl true
  def handle_info(:loop, state) do
    cutoff = System.system_time(:millisecond) - @log_record_ttl_ms

    spec = [{{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}]

    :ets.select_delete(@table, spec)
    loop()
    {:noreply, state}
  end

  @spec loop() :: reference()
  defp loop, do: Process.send_after(self(), :loop, @sweep_interval_ms)
end
