defmodule Otel.Trace.SpanStorage do
  @moduledoc """
  ETS-backed storage for spans across their full lifecycle —
  both active (mutable via `set_attribute` / `add_event`) and
  completed (waiting for export after `end_span`) spans live
  in a single table.

  Each row carries a status marker as its third element,
  following the ETS convention `{key, value, metadata}`:
  `{span_id, %Otel.Trace.Span{}, :active | :completed}`.

  ## Lifecycle

  | Step | Operation | Function |
  |---|---|---|
  | `start_span` | insert as `:active` | `insert_active/1` |
  | `set_attribute`, `add_event`, etc. | mutate active span | `update_active/2` |
  | `end_span` | flip status `:active` → `:completed` | `mark_completed/2` |
  | export timer | take + delete completed batch | `take_completed/1` |

  ## Concurrency

  Multi-writer + single-reader (the Exporter):

  - emit / mutation / end_span run on the caller process and
    write to ETS directly (`write_concurrency` makes this
    lock-free).
  - `take_completed/1` is called only by `SpanExporter`
    (single reader — no take/insert races).
  - Span mutation is normally bound to the process that owns
    the span (the one that called `start_span`); cross-process
    mutation of the same span is rare and treated as caller
    responsibility — `lookup + insert` is *practically*
    race-free under that assumption (same convention the
    previous SpanStorage used).

  ## Backpressure

  `insert_active/1` returns `:dropped` when the ETS table is
  already at `@max_size`, matching the spec's `maxQueueSize`
  semantics for the Batching processor (`trace/sdk.md`
  L1086-L1118). The caller
  (`Otel.Trace.Tracer.start_span`) silently treats the dropped
  span as non-recording — subsequent `set_attribute` /
  `add_event` calls become no-ops because `update_active/2`
  matches no row.

  ## References

  - OTel Trace SDK §Span: `opentelemetry-specification/specification/trace/sdk.md` L692-L944
  - OTel Trace SDK Batching processor: `opentelemetry-specification/specification/trace/sdk.md` L1086-L1118
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
  @spec insert_active(span :: Otel.Trace.Span.t()) :: :ok | :dropped
  def insert_active(%Otel.Trace.Span{span_id: span_id} = span) do
    case :ets.info(@table, :size) do
      n when n >= @max_size ->
        :dropped

      _ ->
        :ets.insert(@table, {span_id, span, :active})
        :ok
    end
  end

  @doc """
  Look up an active span (used by `recording?/1`).
  """
  @spec get_active(span_id :: Otel.Trace.SpanId.t()) :: Otel.Trace.Span.t() | nil
  def get_active(span_id) do
    case :ets.lookup(@table, span_id) do
      [{^span_id, span, :active}] -> span
      _ -> nil
    end
  end

  @doc """
  Apply `fun` to an active span and write the result back. No-op if
  the span is missing or already `:completed`.
  """
  @spec update_active(
          span_id :: Otel.Trace.SpanId.t(),
          fun :: (Otel.Trace.Span.t() -> Otel.Trace.Span.t())
        ) :: :ok
  def update_active(span_id, fun) do
    case :ets.lookup(@table, span_id) do
      [{^span_id, span, :active}] ->
        :ets.insert(@table, {span_id, fun.(span), :active})
        :ok

      _ ->
        :ok
    end
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
