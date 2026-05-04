defmodule Otel.Trace.SpanStorage do
  @moduledoc """
  ETS-backed storage for spans across their full lifecycle —
  both active (mutable via `set_attribute` / `add_event`) and
  completed (waiting for export after `end_span`) spans live
  in a single table.

  Each row is a 4-tuple:

      {span_id, %Otel.Trace.Span{}, status, end_time}

  | Position | Field | Values |
  |---|---|---|
  | 1 | `span_id` | row key |
  | 2 | `%Otel.Trace.Span{}` | span data — written only by `update/1` |
  | 3 | `status` | `0` = active, `1` = completed — flipped only by `mark_completed/2` |
  | 4 | `end_time` | `nil` while active, nanosecond timestamp once completed — set only by `mark_completed/2` |

  Status and end_time are split out of the span struct into
  separate row positions so that `update/1` (writes position 2)
  and `mark_completed/2` (writes positions 3, 4) target
  disjoint fields. Both use a single atomic `select_replace/2`
  BIF, so neither operation can clobber the other regardless
  of how their executions interleave. The struct's `end_time`
  field is set on the read side — `mark_completed/2` and
  `take_completed/1` merge position 4 into the returned
  struct.

  ## Public API — generic CRUD on active spans

  | Function | Role |
  |---|---|
  | `insert/1` | insert a fresh span as active (back-pressure aware) |
  | `get/1` | look up an active span by `span_id` |
  | `update/1` | atomic replace of an active span's data (no-op if already completed) |
  | `mark_completed/2` | atomic flip `0 → 1`, stamp `end_time` |
  | `take_completed/1` | take + delete a batch of completed spans (Exporter only) |

  Mutation flow used by `Otel.Trace.Span`:

      span = SpanStorage.get(span_id)
      new_span = apply_limits(span, ...)   # caller-side transformation
      SpanStorage.update(new_span)         # atomic replace of position 2

  ## Concurrency

  Multi-writer + single-reader (the Exporter):

  - `insert` / `get` / `update` / `mark_completed` run on the
    caller process and write to ETS directly
    (`write_concurrency` makes this lock-free).
  - `update/1` matches active rows and rewrites position 2
    only — preserves end_time at position 4 via `:"$1"`
    capture.
  - `mark_completed/2` matches active rows and rewrites
    positions 3, 4 only — preserves the span struct at
    position 2 via `:"$1"` capture, so it cannot clobber a
    concurrent `update/1`.
  - `take_completed/1` is called only by `SpanExporter`
    (single reader — no take/insert races).

  ## Backpressure

  `insert/1` silently drops the span when the ETS table is
  already at `@max_queue_size`, matching the spec's
  `maxQueueSize` parameter for the Batching processor
  (`trace/sdk.md` L1086-L1118). Drop is a normal lifecycle
  event (per spec) rather than a failure — callers don't
  branch on the result. Subsequent `set_attribute` /
  `add_event` calls on a dropped span become no-ops because
  `update/1` matches no row.

  ## References

  - OTel Trace SDK §Span: `opentelemetry-specification/specification/trace/sdk.md` L692-L944
  - OTel Trace SDK Batching processor: `opentelemetry-specification/specification/trace/sdk.md` L1086-L1118
  - Erlang `:ets.select_replace/2`: <https://www.erlang.org/doc/man/ets#select_replace-2>
  """

  use GenServer

  @table __MODULE__
  # Spec `trace/sdk.md` L1109 §Batching processor `maxQueueSize`:
  # "the maximum queue size. After the size is reached, spans are
  # dropped. The default value is `2048`."
  @max_queue_size 2_048

  # --- Client API ---

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Insert a fresh span as active (`status = 0`, `end_time = nil`).
  Always returns `:ok` — silent drop when the table is at
  `@max_queue_size` (spec `trace/sdk.md` L1109 *"After the size
  is reached, spans are dropped"*: drop is a normal lifecycle
  event, not a failure).

  Drop counting / observability lives inside `SpanStorage` —
  callers don't branch on the result.
  """
  @spec insert(span :: Otel.Trace.Span.t()) :: :ok
  def insert(%Otel.Trace.Span{span_id: span_id} = span) do
    case :ets.info(@table, :size) do
      n when n >= @max_queue_size ->
        :ok

      _ ->
        :ets.insert(@table, {span_id, span, 0, nil})
        :ok
    end
  end

  @doc """
  Look up an active span. Returns `nil` for missing or
  already-completed spans (status = 1 rows are exporter-only).
  """
  @spec get(span_id :: Otel.Trace.SpanId.t()) :: Otel.Trace.Span.t() | nil
  def get(span_id) do
    case :ets.lookup(@table, span_id) do
      [{^span_id, span, 0, _}] -> span
      _ -> nil
    end
  end

  @doc """
  Atomic replace of an active span's data via
  `:ets.select_replace/2`. Writes only position 2 of the row;
  status (position 3) is held at `0`, end_time (position 4) is
  preserved via `:"$1"` capture.

  No-op when the span is missing or already completed — the
  match-spec only matches `status = 0` rows, so completed spans
  are never accidentally re-activated.
  """
  @spec update(span :: Otel.Trace.Span.t()) :: :ok
  def update(%Otel.Trace.Span{span_id: span_id} = new_span) do
    spec = [
      {{span_id, :_, 0, :"$1"}, [], [{{span_id, {:const, new_span}, 0, :"$1"}}]}
    ]

    _ = :ets.select_replace(@table, spec)
    :ok
  end

  @doc """
  Atomically flip an active span to completed (status `0 → 1`,
  stamp `end_time`) via `:ets.select_replace/2`. Writes only
  positions 3 and 4 of the row; the span struct at position 2
  is preserved via `:"$1"` capture, so a concurrent `update/1`
  is never clobbered.

  Returns the span (with `end_time` merged into the struct)
  for caller-side post-processing (e.g. limits warning).
  Returns `nil` if the span was already completed or has been
  dropped.
  """
  @spec mark_completed(
          span_id :: Otel.Trace.SpanId.t(),
          end_time :: non_neg_integer()
        ) :: Otel.Trace.Span.t() | nil
  def mark_completed(span_id, end_time) do
    spec = [
      {{span_id, :"$1", 0, :_}, [], [{{span_id, :"$1", 1, end_time}}]}
    ]

    case :ets.select_replace(@table, spec) do
      1 ->
        # Lookup the just-completed row to return the span the flip
        # actually saw at position 2 (a concurrent `update/1` may have
        # landed between our caller's intent and the atomic flip).
        case :ets.lookup(@table, span_id) do
          [{^span_id, span, 1, _}] -> %{span | end_time: end_time}
          _ -> nil
        end

      0 ->
        nil
    end
  end

  @doc """
  Take up to `n` completed spans atomically (status = 1).
  Merges each row's position-4 `end_time` into the returned
  struct's `end_time` field. Called only by
  `Otel.Trace.SpanExporter` (single reader).
  """
  @spec take_completed(n :: pos_integer()) :: [Otel.Trace.Span.t()]
  def take_completed(n) when n > 0 do
    spec = [{{:"$1", :"$2", 1, :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}]

    case :ets.select(@table, spec, n) do
      :"$end_of_table" ->
        []

      {triples, _continuation} ->
        spans =
          Enum.map(triples, fn {_span_id, span, end_time} ->
            %{span | end_time: end_time}
          end)

        Enum.each(triples, fn {span_id, _, _} -> :ets.delete(@table, span_id) end)
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

    {:ok, @table}
  end
end
