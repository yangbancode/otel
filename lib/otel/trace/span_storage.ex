defmodule Otel.Trace.SpanStorage do
  @moduledoc """
  ETS-backed storage for spans across their full lifecycle —
  both active (mutable via `set_attribute` / `add_event`) and
  completed (waiting for export after `end_span`) spans live
  in a single table.

  Each row is a 4-tuple
  `{span_id, %Otel.Trace.Span{}, status, inserted_at_ms}`
  where `status` is `:active` or `:completed` and
  `inserted_at_ms` is the millisecond timestamp stamped at
  `insert/1` time. The 4th column is *internal-only* — it
  exists solely so the sweep loop can identify stale rows by
  insertion time (not by `span.start_time`, which the caller
  may legitimately backdate via `start_span/3`'s `:start_time`
  opt). It is set once and preserved unchanged by `update/1`
  and `complete/1`.

  ## Public API — generic CRUD on active spans

  | Function | Role |
  |---|---|
  | `insert/1` | insert a fresh span as `:active` (back-pressure aware) |
  | `get/1` | look up an active span by `span_id` |
  | `update/1` | atomic replace of an active span (no-op if already completed) |
  | `complete/1` | atomic flip `:active → :completed` with the caller's final span value |
  | `take_completed/1` | take + delete a batch of completed spans (Exporter only) |

  Mutation flow used by `Otel.Trace.Span`:

      span = SpanStorage.get(span_id)
      new_span = apply_limits(span, ...)   # caller-side transformation
      SpanStorage.update(new_span)         # atomic replace via :ets.select_replace

  Termination flow (`end_span`):

      span = SpanStorage.get(span_id)
      ended = %{span | end_time: end_time}
      SpanStorage.complete(ended)     # atomic flip with the final span value

  ## Concurrency

  Multi-writer + single-reader (the Exporter):

  - `insert` / `get` / `update` / `complete` run on the
    caller process and write to ETS directly
    (`write_concurrency` makes this lock-free).
  - `update/1` and `complete/1` use a single atomic
    `:ets.select_replace/2` BIF whose match-spec only matches
    `:active` rows. Completed spans are never accidentally
    re-mutated.
  - `take_completed/1` is called only by `SpanExporter`
    (single reader — no take/insert races).
  - Span mutation is bound to the process that owns the span
    (the one that called `start_span`); `end_span` is the
    authoritative termination boundary — concurrent mutations
    not committed by the time `complete/1` runs are not
    preserved.

  ## Backpressure

  `insert/1` silently drops the span when the ETS table is
  already at `@max_queue_size`, matching the spec's
  `maxQueueSize` parameter for the Batching processor
  (`trace/sdk.md` L1086-L1118). Drop is a normal lifecycle
  event (per spec) rather than a failure — callers don't
  branch on the result. Subsequent `set_attribute` /
  `add_event` calls on a dropped span become no-ops because
  `update/1` matches no row.

  ## Sweep — stale active spans

  The GenServer runs a self-scheduled sweep every
  `@sweep_interval_ms` (10 minutes) that issues a single
  `:ets.select_delete/2` removing `:active` rows whose
  `inserted_at_ms` (row position 4) is older than
  `@span_ttl_ms` (30 minutes). This is the safety net for
  spans that never reach `end_span` (process crash, dropped
  context, leaked span_ctx) — without it, stale rows would
  accumulate until the `@max_queue_size` backpressure starts
  dropping fresh spans.

  Sweep keys off `inserted_at_ms`, not `span.start_time`,
  because callers may pass a backdated `:start_time` (history
  replay, batch ingestion). Insertion time is the SDK-internal
  signal of "how long has this row sat in storage."

  Defaults match `opentelemetry-erlang`'s `otel_span_sweeper`
  configuration. Sweep strategy is `drop` only — exporting
  fragmentary spans muddles backend data; if observability
  into sweep events is needed later, an
  `end_span`-on-sweep variant can be added.

  ## References

  - OTel Trace SDK §Span: `opentelemetry-specification/specification/trace/sdk.md` L692-L944
  - OTel Trace SDK Batching processor: `opentelemetry-specification/specification/trace/sdk.md` L1086-L1118
  - Erlang `:ets.select_replace/2`: <https://www.erlang.org/doc/man/ets#select_replace-2>
  - Erlang reference sweeper: `opentelemetry-erlang/apps/opentelemetry/src/otel_span_sweeper.erl`
  """

  use GenServer

  @table __MODULE__
  # Spec `trace/sdk.md` L1109 §Batching processor `maxQueueSize`:
  # "the maximum queue size. After the size is reached, spans are
  # dropped. The default value is `2048`."
  @max_queue_size 2_048

  # Sweep cadence and TTL — defaults match `opentelemetry-erlang`'s
  # `otel_span_sweeper` (10-minute interval, 30-minute TTL).
  @sweep_interval_ms :timer.minutes(10)
  @span_ttl_ms :timer.minutes(30)

  # --- Client API ---

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Insert a fresh span as `:active`. Always returns `:ok` —
  silent drop when the table is at `@max_queue_size` (spec
  `trace/sdk.md` L1109 *"After the size is reached, spans are
  dropped"*: drop is a normal lifecycle event, not a failure).

  Drop counting / observability lives inside `SpanStorage` —
  callers don't branch on the result.
  """
  @spec insert(span :: Otel.Trace.Span.t()) :: :ok
  def insert(%Otel.Trace.Span{span_id: span_id} = span) do
    case :ets.info(@table, :size) do
      n when n >= @max_queue_size ->
        :ok

      _ ->
        inserted_at = System.system_time(:millisecond)
        :ets.insert(@table, {span_id, span, :active, inserted_at})
        :ok
    end
  end

  @doc """
  Look up an active span. Returns `nil` for missing or
  already-completed spans (`:completed` rows are exporter-only).
  """
  @spec get(span_id :: Otel.Trace.SpanId.t()) :: Otel.Trace.Span.t() | nil
  def get(span_id) do
    case :ets.lookup(@table, span_id) do
      [{^span_id, span, :active, _}] -> span
      _ -> nil
    end
  end

  @doc """
  Atomic replace of an active span via `:ets.select_replace/2`.

  No-op when the span is missing or already `:completed` —
  the match-spec only matches `:active` rows, so completed
  spans are never accidentally re-activated.
  """
  @spec update(span :: Otel.Trace.Span.t()) :: :ok
  def update(%Otel.Trace.Span{span_id: span_id} = span) do
    spec = [
      {{span_id, :_, :active, :"$1"}, [], [{{span_id, {:const, span}, :active, :"$1"}}]}
    ]

    _ = :ets.select_replace(@table, spec)
    :ok
  end

  @doc """
  Atomically flip an active span to `:completed` with the
  caller's final span value via `:ets.select_replace/2`. The
  caller is expected to have set `end_time` on the span before
  calling.

  Always returns `:ok` — silent no-op when the span is missing
  or already `:completed` (match-spec only matches `:active`
  rows).

  `end_span` is the authoritative termination boundary —
  concurrent mutations not committed by the time this BIF
  runs are not preserved.
  """
  @spec complete(span :: Otel.Trace.Span.t()) :: :ok
  def complete(%Otel.Trace.Span{span_id: span_id} = span) do
    spec = [
      {{span_id, :_, :active, :"$1"}, [], [{{span_id, {:const, span}, :completed, :"$1"}}]}
    ]

    _ = :ets.select_replace(@table, spec)
    :ok
  end

  @doc """
  Take up to `n` `:completed` spans atomically. Called only by
  `Otel.Trace.SpanExporter` (single reader).
  """
  @spec take_completed(n :: pos_integer()) :: [Otel.Trace.Span.t()]
  def take_completed(n) when n > 0 do
    spec = [{{:"$1", :"$2", :completed, :_}, [], [{{:"$1", :"$2"}}]}]

    case :ets.select(@table, spec, n) do
      :"$end_of_table" ->
        []

      {pairs, _continuation} ->
        spans = Enum.map(pairs, fn {_span_id, span} -> span end)
        Enum.each(pairs, fn {span_id, _} -> :ets.delete(@table, span_id) end)
        spans
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

    schedule_sweep()
    {:ok, @table}
  end

  @impl true
  def handle_info(:sweep, state) do
    cutoff = System.system_time(:millisecond) - @span_ttl_ms

    spec = [{{:_, :_, :active, :"$1"}, [{:<, :"$1", cutoff}], [true]}]

    :ets.select_delete(@table, spec)
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_interval_ms)
  end
end
