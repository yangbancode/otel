defmodule Otel.Trace.SpanStorage do
  @moduledoc """
  ETS-backed storage for spans across their full lifecycle —
  both active (mutable via `set_attribute` / `add_event`) and
  completed (waiting for export after `end_span`) spans live
  in a single table.

  Each row carries a status marker as its third element,
  following the ETS convention `{key, value, metadata}`:
  `{span_id, %Otel.Trace.Span{}, :active | :completed}`.

  ## Public API — generic CRUD on active spans

  | Function | Role |
  |---|---|
  | `insert/1` | insert a fresh span as `:active` (back-pressure aware) |
  | `get/1` | look up an active span by `span_id` |
  | `update/1` | atomic replace of an active span (no-op if already completed) |
  | `mark_completed/2` | flip status `:active` → `:completed`, stamp `end_time` |
  | `take_completed/1` | take + delete a batch of completed spans (Exporter only) |

  Mutation flow used by `Otel.Trace.Span`:

      span = SpanStorage.get(span_id)
      new_span = apply_limits(span, ...)   # caller-side transformation
      SpanStorage.update(new_span)         # atomic replace via :ets.select_replace

  ## Concurrency

  Multi-writer + single-reader (the Exporter):

  - `insert` / `get` / `update` run on the caller process and
    write to ETS directly (`write_concurrency` makes this
    lock-free).
  - `update/1` uses `:ets.select_replace/2` — a single BIF that
    matches `:active` rows and replaces atomically. No race
    window between match and replace.
  - `take_completed/1` is called only by `SpanExporter`
    (single reader — no take/insert races).
  - Span mutation is normally bound to the process that owns
    the span (the one that called `start_span`); cross-process
    mutation of the same span is rare and treated as caller
    responsibility.

  ## Backpressure

  `insert/1` returns `:dropped` when the ETS table is already
  at `@max_size`, matching the spec's `maxQueueSize` semantics
  for the Batching processor (`trace/sdk.md` L1086-L1118). The
  caller (`Otel.Trace.Tracer.start_span`) silently treats the
  dropped span as non-recording — subsequent `set_attribute` /
  `add_event` calls become no-ops because `update/1` matches
  no row.

  ## References

  - OTel Trace SDK §Span: `opentelemetry-specification/specification/trace/sdk.md` L692-L944
  - OTel Trace SDK Batching processor: `opentelemetry-specification/specification/trace/sdk.md` L1086-L1118
  - Erlang `:ets.select_replace/2`: <https://www.erlang.org/doc/man/ets#select_replace-2>
  """

  use GenServer

  @table __MODULE__
  @max_size 2_048

  # --- Client API ---

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Insert a fresh span as `:active`. Returns `:dropped` when the
  table is at `@max_size` (back-pressure).
  """
  @spec insert(span :: Otel.Trace.Span.t()) :: :ok | :dropped
  def insert(%Otel.Trace.Span{span_id: span_id} = span) do
    case :ets.info(@table, :size) do
      n when n >= @max_size ->
        :dropped

      _ ->
        :ets.insert(@table, {span_id, span, :active})
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
      [{^span_id, span, :active}] -> span
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
  def update(%Otel.Trace.Span{span_id: span_id} = new_span) do
    spec = [
      {{span_id, :"$1", :active}, [], [{{span_id, {:const, new_span}, :active}}]}
    ]

    _ = :ets.select_replace(@table, spec)
    :ok
  end

  @doc """
  Mark an active span as `:completed`, stamping `end_time`.
  Returns the completed span for caller-side post-processing
  (e.g. limits warning).
  """
  @spec mark_completed(
          span_id :: Otel.Trace.SpanId.t(),
          end_time :: non_neg_integer()
        ) :: Otel.Trace.Span.t() | nil
  def mark_completed(span_id, end_time) do
    case :ets.lookup(@table, span_id) do
      [{^span_id, span, :active}] ->
        ended = %{span | end_time: end_time}
        :ets.insert(@table, {span_id, ended, :completed})
        ended

      _ ->
        nil
    end
  end

  @doc """
  Take up to `n` `:completed` spans atomically. Called only by
  `Otel.Trace.SpanExporter` (single reader).
  """
  @spec take_completed(n :: pos_integer()) :: [Otel.Trace.Span.t()]
  def take_completed(n) when n > 0 do
    spec = [{{:"$1", :"$2", :completed}, [], [{{:"$1", :"$2"}}]}]

    case :ets.select(@table, spec, n) do
      :"$end_of_table" ->
        []

      {pairs, _continuation} ->
        spans = Enum.map(pairs, &elem(&1, 1))
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

    {:ok, @table}
  end
end
