defmodule Otel.Trace.SpanStorage do
  @moduledoc """
  ETS-backed storage for spans across their full lifecycle —
  active (mutable, `set_attribute` / `add_event` 가능) 와
  completed (`end_span` 후 export 대기) 둘 다 한 table 에 보관.

  Row 의 status field 로 두 상태 구별:
  `{span_id, %Otel.Trace.Span{}, :active | :completed}` —
  ETS 관용 `{key, value, metadata}` 패턴 따름.

  ## Lifecycle

  | Step | Operation | Function |
  |---|---|---|
  | `start_span` | active 상태로 insert | `insert_active/1` |
  | `set_attribute`, `add_event`, etc. | active span 만 mutate | `update_active/2` |
  | `end_span` | active → completed status 전환 | `mark_completed/2` |
  | export timer | completed batch take + delete | `take_completed/1` |

  ## Concurrency

  Multi-writer + single-reader (Exporter):
  - emit/mutation/end_span 은 *각 caller process 에서 직접 ETS 조작*
    (write_concurrency 로 lock-free)
  - take_completed 는 *SpanExporter 만* 호출 (single reader, race 없음)
  - Span mutation 은 *보통 같은 process 가 자기 span 만 만짐* — practical
    race-free (현재 SpanStorage 가 같은 가정)

  ## Backpressure

  `insert_active/1` 가 ETS size 가 `@max_size` 초과 시 `:dropped` 반환.
  Caller (`Otel.Trace.Tracer.start_span`) 는 이때 *non-recording span*
  로 fall back. spec `trace/sdk.md` Batching processor 의 `maxQueueSize`
  와 동일 의미.

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
        Enum.each(pairs, fn {span_id, _} -> :ets.delete(@table, span_id) end)
        Enum.map(pairs, &elem(&1, 1))
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
