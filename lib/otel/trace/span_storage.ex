defmodule Otel.Trace.SpanStorage do
  @moduledoc """
  ETS-backed storage for active spans.

  A GenServer that owns the ETS table. The table is `public` with
  `write_concurrency` and `read_concurrency` so any process can
  read/write spans without going through this server.

  ## Design notes

  ### ETS layout

  A single named table (`#{inspect(__MODULE__)}`) stores every active
  span. The table key is the 64-bit `span_id`, giving O(1) lookup and
  removal. The value is the internal `Otel.Trace.Span.Impl` struct
  carrying all mutable fields (name, kind, attributes, events, links,
  status, trace/span identifiers, timestamps, recording flag,
  instrumentation scope).

  The GenServer's sole job is to own the table so that it lives with
  the SDK supervisor and dies with it. Reads and writes happen
  **directly against the ETS table** from whichever process is holding
  the span — the GenServer is not on the hot path for any operation.

  ### Concurrency model

  Spans are typically mutated only by the process that created them,
  reached through the current Ctx. `write_concurrency` + `read_concurrency`
  allow lock-free parallel access from multiple processes on the rare
  cross-process path (e.g. a span handed across `Task.async/1`). No
  additional synchronisation is required.

  ### Lifecycle

  | Step | Operation | ETS call |
  |---|---|---|
  | `start_span` | insert struct | `insert/2` |
  | `set_attribute`, `add_event`, ... | mutate in place | `insert/2` |
  | `end_span` | remove and hand to processors | `take/1` |

  `take/1` is used rather than `lookup + delete` so the span leaves the
  table atomically — no window in which a second reader could see an
  ended-but-still-stored span.
  """

  use GenServer

  @table __MODULE__

  # --- Client API ---

  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Inserts a span into the table.
  """
  @spec insert(span :: Otel.Trace.Span.Impl.t()) :: true
  def insert(span) do
    :ets.insert(@table, {span.span_id, span})
  end

  @doc """
  Looks up a span by span_id.
  """
  @spec get(span_id :: Otel.Trace.SpanId.t()) :: Otel.Trace.Span.Impl.t() | nil
  def get(span_id) do
    case :ets.lookup(@table, span_id) do
      [{^span_id, span}] -> span
      [] -> nil
    end
  end

  @doc """
  Removes and returns a span by span_id.
  """
  @spec take(span_id :: Otel.Trace.SpanId.t()) :: Otel.Trace.Span.Impl.t() | nil
  def take(span_id) do
    case :ets.take(@table, span_id) do
      [{^span_id, span}] -> span
      [] -> nil
    end
  end

  @doc """
  Returns the ETS table name.
  """
  @spec table() :: atom()
  def table, do: @table

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    table =
      :ets.new(@table, [
        :named_table,
        :public,
        :set,
        {:write_concurrency, true},
        {:read_concurrency, true}
      ])

    {:ok, %{table: table}}
  end
end
